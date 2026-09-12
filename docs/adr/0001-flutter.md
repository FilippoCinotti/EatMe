# 0001: Flutter for shared mobile UI

Status: accepted for the application implementation.

## Decision

Use Flutter for Android and iOS with native plugins for camera, authentication, secure storage, notifications and purchases. Keep platform configuration in versioned native runners. Shared code reduces duplicated business UI; platform-specific lifecycle validation remains required.

## Consequences

The application frame respects operating-system display features and keeps navigation, pages and dialogs inside an unobstructed display region. Content has a maximum reading width and remains scrollable with larger text. Synthetic hinge tests verify generic foldable layouts; named future hardware still requires validation on the actual device and operating system.

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
