# Contributing to TrackPeek

TrackPeek is a native macOS app built with Swift 6, SwiftUI, and narrow AppKit integration. Use the Xcode project for app builds and tests; the root Package.swift does not configure the complete app.

## Local setup

Install Xcode with Swift 6 support and XcodeGen. In project.yml, configure DEVELOPMENT_TEAM and signing for the app, helper, and tests to match your own local certificate. Regenerate the project after source or configuration changes:

```sh
xcodegen generate
./script/build_and_run.sh --verify
```

The build script stops the running TrackPeek process. Do not replace an installed app or change personal playback, system permissions, or login registration as part of automated checks.

## Verification

The same entry point runs locally and in GitHub Actions. Install XcodeGen,
Actionlint and ShellCheck (`brew install xcodegen actionlint shellcheck`), then:

```sh
./script/ci.sh checks  # Translation/script tests, workflow/shell lint, project consistency
./script/ci.sh test    # App-hosted tests and coverage, with temporary ad-hoc signing
./script/ci.sh build   # Universal Release build for Apple silicon and Intel
./script/ci.sh         # All stages
```

CI does not require your Apple certificate, signing keys, or release secrets.
It keeps logs and test results under `.build/ci/`; GitHub also uploads reports
as workflow artifacts. These ad-hoc builds are verification artifacts, not
distributable releases. The workflow does not install the app, start personal
playback services, or publish a release. Required check names are documented in
[Git and pull requests](docs/GIT_WORKFLOW.md).

For targeted app debugging with your existing signing configuration:

```sh
xcodebuild \
  -project TrackPeek.xcodeproj \
  -scheme TrackPeek \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/xcode \
  test

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s script/tests -v
python3 script/validate_localizations.py
mkdir -p .build
xcrun swiftc -parse-as-library -D SIGNATURE_TESTS \
  -module-cache-path .build/release-swift-cache \
  script/verify_update.swift script/tests/VerifyUpdateTests.swift \
  -o .build/verify-update-tests
.build/verify-update-tests
bash -n script/build_and_run.sh script/release.sh
git diff --check
```

For an Intel development Mac, use arch=x86_64 in the test destination. App-hosted tests suppress normal startup services and use substitute playback providers, clocks, and services. Add regression coverage for behavior changes; use native UI checks for focus, VoiceOver labels, and panel interactions.

See [localization](docs/LOCALIZATION.md) for English, Ukrainian and Russian string catalogs. Preserve formatting arguments and native plural forms; the validator checks translation coverage and argument types.

Report the OS, Xcode version, checks run, and scenarios that need hardware or permission testing. Physical notch placement, monitor reconnection, macOS 14 runtime behavior, and actual permission dialogs require separate manual verification.

## Changes and review

- Keep playback state and routing in the existing services/stores. Views consume shared state rather than starting independent polling.
- Preserve saved preferences and bounded caches. Do not introduce listening history or replay a playback command after a timeout.
- Use cancellation and source/track identity to discard obsolete work. Keep timers and audio capture tied to their visible consumers.
- Prefer native controls with meaningful accessibility labels. Respect Reduce Motion and resource modes.
- Treat project.yml as the project definition and commit its regenerated Xcode project together with source changes. Keep build output, signing keys, and local credentials out of Git.
- Keep commits focused and describe the resulting behavior and verification in a pull request. Follow the [Git workflow](docs/GIT_WORKFLOW.md) for branches, required checks, merging, dependency updates and recovery. Do not rewrite shared history or force-push.

See [release preparation](docs/RELEASING.md) for maintainer-only packaging and publication. Public publication is a separate action from building local artifacts.
