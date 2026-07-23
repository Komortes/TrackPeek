#import "TPAudioLevelAnalyzer.h"

#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/AudioHardwareTapping.h>
#import <CoreAudio/CATapDescription.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <limits>

namespace {

constexpr size_t kBandCount = 7;
constexpr std::array<double, kBandCount> kBandFrequencies = {
    80.0, 160.0, 320.0, 640.0, 1250.0, 2500.0, 5000.0
};

constexpr AudioObjectPropertyAddress PropertyAddress(
    AudioObjectPropertySelector selector,
    AudioObjectPropertyScope scope = kAudioObjectPropertyScopeGlobal,
    AudioObjectPropertyElement element = kAudioObjectPropertyElementMain
) noexcept {
    return {selector, scope, element};
}

struct AnalyzerState {
    AudioObjectID tapID = kAudioObjectUnknown;
    AudioObjectID deviceID = kAudioObjectUnknown;
    AudioDeviceIOProcID ioProcID = nullptr;
    AudioStreamBasicDescription format = {};
    std::array<double, kBandCount> coefficients = {};
    std::array<std::atomic<float>, kBandCount> levels;

    AnalyzerState() {
        for (auto& level : levels) {
            level.store(0.0f, std::memory_order_relaxed);
        }
    }
};

NSError *MakeError(OSStatus status, NSString *operation) {
    NSString *description = [NSString stringWithFormat:@"%@ failed (%d)", operation, status];
    return [NSError errorWithDomain:@"com.trackpeek.audio-tap"
                               code:status
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

AudioObjectID ProcessObjectForPID(pid_t pid, OSStatus& status) {
    auto address = PropertyAddress(kAudioHardwarePropertyTranslatePIDToProcessObject);
    AudioObjectID processObject = kAudioObjectUnknown;
    UInt32 dataSize = sizeof(processObject);
    status = AudioObjectGetPropertyData(
        kAudioObjectSystemObject,
        &address,
        sizeof(pid),
        &pid,
        &dataSize,
        &processObject
    );
    return processObject;
}

CFStringRef CopyTapUID(AudioObjectID tapID, OSStatus& status) {
    auto address = PropertyAddress(kAudioTapPropertyUID);
    CFStringRef tapUID = nullptr;
    UInt32 dataSize = sizeof(tapUID);
    status = AudioObjectGetPropertyData(
        tapID,
        &address,
        0,
        nullptr,
        &dataSize,
        &tapUID
    );
    return tapUID;
}

AudioStreamBasicDescription TapFormat(AudioObjectID tapID, OSStatus& status) {
    auto address = PropertyAddress(kAudioTapPropertyFormat);
    AudioStreamBasicDescription format = {};
    UInt32 dataSize = sizeof(format);
    status = AudioObjectGetPropertyData(
        tapID,
        &address,
        0,
        nullptr,
        &dataSize,
        &format
    );
    return format;
}

float MonoSample(const AudioBufferList *bufferList, UInt32 frame) noexcept {
    float sum = 0.0f;
    UInt32 channelCount = 0;

    for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; ++bufferIndex) {
        const auto& buffer = bufferList->mBuffers[bufferIndex];
        if (buffer.mData == nullptr || buffer.mNumberChannels == 0) {
            continue;
        }

        const auto *samples = static_cast<const Float32 *>(buffer.mData);
        for (UInt32 channel = 0; channel < buffer.mNumberChannels; ++channel) {
            sum += samples[frame * buffer.mNumberChannels + channel];
            ++channelCount;
        }
    }

    return channelCount > 0 ? sum / static_cast<float>(channelCount) : 0.0f;
}

UInt32 AvailableFrames(const AudioBufferList *bufferList) noexcept {
    UInt32 frameCount = std::numeric_limits<UInt32>::max();
    for (UInt32 index = 0; index < bufferList->mNumberBuffers; ++index) {
        const auto& buffer = bufferList->mBuffers[index];
        if (buffer.mNumberChannels == 0) {
            continue;
        }
        const UInt32 frames = buffer.mDataByteSize
            / (sizeof(Float32) * buffer.mNumberChannels);
        frameCount = std::min(frameCount, frames);
    }
    return frameCount == std::numeric_limits<UInt32>::max() ? 0 : frameCount;
}

void Analyze(const AudioBufferList *bufferList, AnalyzerState& state) noexcept {
    if (bufferList == nullptr || bufferList->mNumberBuffers == 0) {
        return;
    }

    const bool isFloat = (state.format.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    if (state.format.mFormatID != kAudioFormatLinearPCM || !isFloat
        || state.format.mBitsPerChannel != 32 || state.format.mSampleRate <= 0) {
        return;
    }

    const UInt32 frameCount = AvailableFrames(bufferList);
    if (frameCount < 16) {
        return;
    }

    std::array<double, kBandCount> s1 = {};
    std::array<double, kBandCount> s2 = {};
    double meanSquare = 0.0;
    for (UInt32 frame = 0; frame < frameCount; ++frame) {
        const double sample = std::min(
            1.0,
            std::max(-1.0, static_cast<double>(MonoSample(bufferList, frame)))
        );
        meanSquare += sample * sample;

        for (size_t band = 0; band < kBandCount; ++band) {
            const double next = sample
                + state.coefficients[band] * s1[band]
                - s2[band];
            s2[band] = s1[band];
            s1[band] = next;
        }
    }

    const double rms = std::sqrt(meanSquare / frameCount);
    for (size_t band = 0; band < kBandCount; ++band) {
        const double power = std::max(
            0.0,
            s1[band] * s1[band] + s2[band] * s2[band]
                - state.coefficients[band] * s1[band] * s2[band]
        );
        const double amplitude = 2.0 * std::sqrt(power) / frameCount;
        const double weighted = std::sqrt(std::min(
            1.0,
            std::max(0.0, amplitude * (3.1 + band * 0.17) + rms * 0.55)
        ));

        const float previous = state.levels[band].load(std::memory_order_relaxed);
        const float target = static_cast<float>(weighted);
        const float smoothing = target > previous ? 0.64f : 0.20f;
        state.levels[band].store(
            previous + (target - previous) * smoothing,
            std::memory_order_relaxed
        );
    }
}

OSStatus AnalyzerIOProc(
    AudioObjectID,
    const AudioTimeStamp *,
    const AudioBufferList *inputData,
    const AudioTimeStamp *,
    AudioBufferList *,
    const AudioTimeStamp *,
    void *clientData
) noexcept {
    auto *state = static_cast<AnalyzerState *>(clientData);
    if (state != nullptr) {
        Analyze(inputData, *state);
    }
    return noErr;
}

} // namespace

@interface TPAudioLevelAnalyzer () {
    AnalyzerState *_state;
}
@end

@implementation TPAudioLevelAnalyzer

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _state = new AnalyzerState();
    }
    return self;
}

- (void)dealloc {
    [self stop];
    delete _state;
}

- (BOOL)isRunning {
    return _state->ioProcID != nullptr;
}

- (BOOL)startForProcessIdentifier:(pid_t)processIdentifier
                            error:(NSError * _Nullable __autoreleasing *)error {
    if (@available(macOS 14.2, *)) {
        [self stop];

        OSStatus status = noErr;
        const AudioObjectID processObject = ProcessObjectForPID(processIdentifier, status);
        if (status != noErr || processObject == kAudioObjectUnknown) {
            if (error != nullptr) {
                *error = MakeError(status, @"Finding Spotify audio process");
            }
            return NO;
        }

        CATapDescription *description = [[CATapDescription alloc]
            initStereoMixdownOfProcesses:@[@(processObject)]];
        description.name = @"TrackPeek Spotify spectrum";
        [description setPrivate:YES];
        description.muteBehavior = CATapUnmuted;

        status = AudioHardwareCreateProcessTap(description, &_state->tapID);
        if (status != noErr) {
            if (error != nullptr) {
                *error = MakeError(status, @"Creating Spotify audio tap");
            }
            [self stop];
            return NO;
        }

        _state->format = TapFormat(_state->tapID, status);
        if (status != noErr) {
            if (error != nullptr) {
                *error = MakeError(status, @"Reading audio tap format");
            }
            [self stop];
            return NO;
        }
        for (size_t band = 0; band < kBandCount; ++band) {
            _state->coefficients[band] = 2.0 * std::cos(
                2.0 * M_PI * kBandFrequencies[band] / _state->format.mSampleRate
            );
        }

        CFStringRef tapUID = CopyTapUID(_state->tapID, status);
        if (status != noErr || tapUID == nullptr) {
            if (error != nullptr) {
                *error = MakeError(status, @"Reading audio tap identifier");
            }
            [self stop];
            return NO;
        }

        NSString *deviceUID = NSUUID.UUID.UUIDString;
        NSDictionary *tapEntry = @{
            @(kAudioSubTapUIDKey): (__bridge NSString *)tapUID
        };
        NSDictionary *deviceDescription = @{
            @(kAudioAggregateDeviceNameKey): @"TrackPeek spectrum device",
            @(kAudioAggregateDeviceUIDKey): deviceUID,
            @(kAudioAggregateDeviceTapListKey): @[tapEntry],
            @(kAudioAggregateDeviceIsPrivateKey): @YES,
            @(kAudioAggregateDeviceTapAutoStartKey): @YES,
        };
        status = AudioHardwareCreateAggregateDevice(
            (__bridge CFDictionaryRef)deviceDescription,
            &_state->deviceID
        );
        CFRelease(tapUID);
        if (status != noErr) {
            if (error != nullptr) {
                *error = MakeError(status, @"Creating spectrum input device");
            }
            [self stop];
            return NO;
        }

        status = AudioDeviceCreateIOProcID(
            _state->deviceID,
            AnalyzerIOProc,
            _state,
            &_state->ioProcID
        );
        if (status == noErr) {
            status = AudioDeviceStart(_state->deviceID, _state->ioProcID);
        }
        if (status != noErr) {
            if (error != nullptr) {
                *error = MakeError(status, @"Starting spectrum analysis");
            }
            [self stop];
            return NO;
        }
        return YES;
    }

    if (error != nullptr) {
        *error = [NSError errorWithDomain:@"com.trackpeek.audio-tap"
                                     code:-1
                                 userInfo:@{
            NSLocalizedDescriptionKey: @"Music-synced spectrum requires macOS 14.2 or later"
        }];
    }
    return NO;
}

- (void)stop {
    if (_state == nullptr) {
        return;
    }

    if (_state->ioProcID != nullptr && _state->deviceID != kAudioObjectUnknown) {
        AudioDeviceStop(_state->deviceID, _state->ioProcID);
        AudioDeviceDestroyIOProcID(_state->deviceID, _state->ioProcID);
        _state->ioProcID = nullptr;
    }
    if (_state->deviceID != kAudioObjectUnknown) {
        AudioHardwareDestroyAggregateDevice(_state->deviceID);
        _state->deviceID = kAudioObjectUnknown;
    }
    if (_state->tapID != kAudioObjectUnknown) {
        if (@available(macOS 14.2, *)) {
            AudioHardwareDestroyProcessTap(_state->tapID);
        }
        _state->tapID = kAudioObjectUnknown;
    }
    for (auto& level : _state->levels) {
        level.store(0.0f, std::memory_order_relaxed);
    }
}

- (NSArray<NSNumber *> *)currentLevels {
    NSMutableArray<NSNumber *> *levels = [NSMutableArray arrayWithCapacity:kBandCount];
    for (const auto& level : _state->levels) {
        [levels addObject:@(level.load(std::memory_order_relaxed))];
    }
    return levels;
}

@end
