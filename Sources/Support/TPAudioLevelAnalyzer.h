#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Real-time-safe Core Audio bridge. The audio callback writes only to atomics;
/// Swift reads snapshots from the main actor.
@interface TPAudioLevelAnalyzer : NSObject

@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (BOOL)startForProcessIdentifier:(pid_t)processIdentifier
                            error:(NSError * _Nullable * _Nullable)error;
- (void)stop;
- (NSArray<NSNumber *> *)currentLevels;

@end

NS_ASSUME_NONNULL_END
