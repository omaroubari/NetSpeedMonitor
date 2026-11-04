# Repository Guidelines

## Project Structure & Module Organization

Network Pulse is a native macOS app targeting macOS 14.6+. Its Xcode project and build scheme retain the name `NetSpeedMonitor`.

- `NetSpeedMonitor/`: SwiftUI app entry point, shared monitoring state, and menu-bar UI.
- `Views/`, `Models/`, `Stores/`, and `Support/` inside that directory: screens, data types, SwiftData persistence, and platform helpers.
- `NetTrafficStatCpp.*` and `NetTrafficStatOC.*`: C++ traffic collection and its Objective-C++ bridge to Swift.
- `Assets.xcassets` and `Preview Content/`: app assets and preview resources; `design/` contains icon source material.
- `docs/adr/`, `UBIQUITOUS_LANGUAGE.md`, and `ROADMAP.md`: architectural decisions, canonical terminology, and planned features.

## Build, Test, and Development Commands

Run from the repository root with Xcode installed and selected:

```sh
./script/build_and_run.sh            # Stop the app, build Debug, and launch
./script/build_and_run.sh --verify   # Also verify the process is running
./script/build_and_run.sh --debug    # Build and launch under LLDB
./script/build_and_run.sh --logs     # Launch and stream application logs
```

Build without launching:

```sh
xcodebuild -project NetSpeedMonitor.xcodeproj -scheme NetSpeedMonitor \
  -configuration Debug -destination 'platform=macOS' build
```

CI builds a universal Release app for Apple silicon and Intel.

## Coding Style & Naming Conventions

Use four-space indentation. Follow existing Swift style: `UpperCamelCase` types, `lowerCamelCase` members, and filenames matching their primary type. Keep views focused and separate persistence from presentation. Respect `@MainActor` UI state and the database actor's isolation.

Use `.clang-format` for C++ formatting; it specifies C++17, spaces, and a 120-column limit. No Swift formatter or linter is configured.

## Testing Guidelines

No automated test target or coverage threshold currently exists. Build and manually verify affected behavior: dashboard/menu-bar rates, pause/resume, interface selection, VPN traffic, and history persistence as applicable. Record checks in the PR. Process verification alone does not validate UI behavior.

When adding a test target, use descriptive names such as `testCounterWraparoundProducesCorrectDelta` and document its run command.

## Commit & Pull Request Guidelines

History uses both imperative subjects and prefixes such as `feat:`, `fix:`, `chore:`, and `design:`. Keep commits focused. PRs should explain the problem, resulting behavior, validation, and relevant issues; include screenshots for UI changes. Update terminology, ADRs, or roadmap checkboxes when applicable.

## Working Agreements

Explain concepts for a junior MacOS engineer. Teach APIs and engineering tradeoffs as work proceeds. Distinguish current behavior from roadmap proposals, and explicitly document changes to traffic accounting or retention semantics.

## Evolving Conventions & Architecture

Contributors may refactor or replace existing conventions, designs, and patterns when the targeted feature benefits. For example, evaluate Apple's Network Extension framework as a replacement for interface-based measurement when implementing per-app monitoring and blocking. Keep changes tied to the feature and validate affected behavior. Agents must notify the user when taking this approach, explain the benefits and tradeoffs, and summarize the resulting changes. Record significant architectural decisions in `docs/adr/` and update affected documentation.
