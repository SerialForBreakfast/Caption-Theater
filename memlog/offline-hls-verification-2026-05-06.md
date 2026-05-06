# Offline HLS verification

- **2026-05-06:** `xcodebuild -scheme CaptionTheater -destination 'generic/platform=tvOS Simulator' build-for-testing` completed successfully after adding `CaptionTheaterOfflineHLSBundleTests` and `import Foundation` in `CaptionTheaterLaunchConfigurationTests`.
- **Simulator note:** Full-scheme `xcodebuild test` may hit Mach `-308` / lost connection on **`CaptionTheaterUITests`** (template runner). **Unit + snapshot tests all passed**, including **`CaptionTheaterOfflineHLSBundleTests`**. Reliable CLI path:  
  `xcodebuild -scheme CaptionTheater -destination 'platform=tvOS Simulator,name=Apple TV' test -skip-testing:CaptionTheaterUITests`
- **Manual QA:** Disable network → Feature toggles → **Offline HLS mock (5 min, UW + subs)** → confirm playback + Caption Theater subtitle reception.
