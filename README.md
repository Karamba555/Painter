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
- AR Trace: RealityKit rendering, detected-table raycast placement, adjustable width/rotation/opacity, lock and explicit recovery when tracking becomes unreliable.
- Saved tracing transforms, project detail, rename/delete, direct camera capture of finished artwork and image sharing.
- Photo import using PhotosPicker, simple/detailed Core Image outlines, first-photo-project allowance, saved projects, finished artwork photo import and PDF sharing.
- Profile with actual progress, active-session time, achievements, projects, interests and subscription controls.
- Custom weekly paywall, StoreKit 2 products/verified entitlements, transaction updates, restore, pending/cancel/error states.
- VoiceOver labels, Dynamic Type-aware fonts, native navigation/tab bars and Reduce Motion poster fallbacks.

## Explicit next milestones

- **AR needs physical-device validation.** Surface anchoring is implemented; stability on ordinary paper under hand occlusion is not yet measured. See `Docs/AR-DEVICE-TEST.md`. The table is the anchor; moving the paper requires realignment.
- **AI code is implemented; the service is not deployed.** `Backend/` contains an executable OpenAI service with Apple subscription verification, persistent limits, idempotent retries and tests. The iOS client handles generation, preview, quota/errors and tracing. Configure the server secrets and Xcode `TRACE_API_BASE_URL` to enable it. See `Backend/README.md`. No OpenAI key is bundled in the app.
- Lesson instructions are initial authored content; the illustrations are full references, not separately drawn art for every step. Expand and review the lesson content before release.
- Animation polish is deferred as requested. The existing Welcome and three mode videos are bundled locally.
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

Unit tests cover personalization, free-content coverage, photo/AI access, persistence, saved transforms, lesson progression, activity, image/PDF processing and the AI HTTP client. UI tests cover onboarding, tabs, lesson resume, catalog, mode selection, Screen Trace and paywall. Backend tests run separately with `cd Backend && npm ci && npm test`; they do not call paid services.

## Structure

- `Painter/App`: app entry point, tab navigation and routes.
- `Painter/Design`: palette, DM Sans typography, reusable controls and local loop player.
- `Painter/Models`: catalog, lessons and versioned local state.
- `Painter/Features`: screen implementations.
- `Painter/Services`: image processing/files/PDF, camera and StoreKit.
- `Painter/Resources`: Figma artwork, SVG icons, videos, fonts, privacy manifest and StoreKit test configuration.

Photos and projects stay on the device. There are no analytics, advertising SDKs or photo uploads. When AI is configured and requested, the text prompt is sent through the backend to OpenAI, and the signed subscription is verified with Apple. The server keeps hashed quota identifiers and generated results for safe retries. Deleting the app deletes local projects; exported files remain wherever the user saved them.

Design source: [Trace Studio in Figma](https://www.figma.com/design/daGETE9rktlcfIzQGv0j2x). Artwork and icon exports come from that project. DM Sans is bundled under the SIL Open Font License; see `Painter/Resources/Fonts/OFL.txt`.
