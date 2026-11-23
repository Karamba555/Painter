# Painter · Trace Studio

A native SwiftUI implementation of the Trace Studio Figma design. iOS 17+, iPhone and iPad, no third-party app dependencies.

## Open and run

1. Open `Painter.xcodeproj` in Xcode 16 or newer.
2. Select the **Painter** scheme and an iPhone simulator, then Run.
3. For a physical phone, select your Apple development team under Signing & Capabilities. Set your own bundle identifier if needed.

The project and shared scheme are committed; no package installation or project generation is required. If source files are added outside Xcode, `python3 Scripts/generate_project.py` regenerates the project deterministically.

## Implemented

- Welcome with the existing local video loop; optional multi-select interests quiz and skip-to-home.
- Home: photo/AI entry points, seven-day challenge, Trending, personalized For You, catalog navigation.
- Five topic collections, difficulty filters, Free/Pro labels and persisted favorites.
- Lessons with a complete free lesson at each difficulty, seven challenge days, saved steps and completion tracking.
- Three-mode chooser and setup instructions using the current demonstration loops.
- Camera Trace: live rear camera, adjustable outline size/position/opacity and a lock control. Requires a physical iPhone/iPad camera.
- Screen Trace: bright screen, adjustable outline, lock, and brightness restoration on exit/background.
- Photo import using PhotosPicker, simple/detailed Core Image outlines, first-photo-project allowance, saved projects, finished artwork photo import and PDF sharing.
- Profile with actual progress, active-session time, achievements, projects, interests and subscription controls.
- Custom weekly paywall, StoreKit 2 products/verified entitlements, transaction updates, restore, pending/cancel/error states.
- VoiceOver labels, Dynamic Type-aware fonts, native navigation/tab bars and Reduce Motion poster fallbacks.

## Explicit next milestones

- **AR Trace is a demonstration only.** Validate anchoring on ordinary paper and partial hand occlusion before adding an AR implementation. No fake surface tracking is presented as functional.
- **AI creation is a UI preview only.** No provider, API keys, generation quota or backend has been invented. The paywall does not sell AI as a currently available feature.
- Lesson instructions are initial authored content; the illustrations are full references, not separately drawn art for every step. Expand and review the lesson content before release.
- Animation polish is deferred as requested. The existing Welcome and three mode videos are bundled locally.
- Artwork photos can be imported from Photos; direct capture of the finished work is a later addition.
- Production App Store Connect product, signing team, final app icon, published privacy/support URLs and release metadata still need configuration.

## Subscription testing

The intended US price is **$5.99/week**, without a free trial. Runtime prices come from StoreKit; the Figma price is shown as a preview until a product loads. An unavailable product never grants Pro access.

For local purchase testing, edit the Painter scheme → Run → Options → StoreKit Configuration and choose `Painter/Resources/TraceStudio.storekit`. The default scheme deliberately leaves local billing simulation off. Production product ID: `com.karamba555.painter.pro.weekly` (change in `PurchaseStore.swift` to match App Store Connect). Use Xcode’s StoreKit transaction manager to test renewals, cancellations and refunds.

## Validation

GitHub Actions (`.github/workflows/ios.yml`) builds and runs XCTest plus UI navigation tests on a macOS iOS simulator. Results and screenshots are retained as the `ios-test-results` artifact. Locally:

```sh
xcodebuild test -project Painter.xcodeproj -scheme Painter \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Unit tests cover topic personalization, free-content coverage, free-photo gating/resume, persistence, lesson progression and activity accounting. UI tests cover onboarding, tabs and lesson resume after relaunch.

## Structure

- `Painter/App`: app entry point, tab navigation and routes.
- `Painter/Design`: palette, DM Sans typography, reusable controls and local loop player.
- `Painter/Models`: catalog, lessons and versioned local state.
- `Painter/Features`: screen implementations.
- `Painter/Services`: image processing/files/PDF, camera and StoreKit.
- `Painter/Resources`: Figma artwork, SVG icons, videos, fonts, privacy manifest and StoreKit test configuration.

User data stays on the device. There are no analytics, advertising SDKs or photo uploads. Deleting the app deletes its local projects; exported PDFs remain wherever the user saved them.

Design source: [Trace Studio in Figma](https://www.figma.com/design/daGETE9rktlcfIzQGv0j2x). Artwork and icon exports come from that project. DM Sans is bundled under the SIL Open Font License; see `Painter/Resources/Fonts/OFL.txt`.
