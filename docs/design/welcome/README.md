# Approved welcome screen

The user approved the dark and light welcome mockups on 7 October 2026 and requested that both be implemented exactly as proposed.

The native landing screen preserves the avocado, tomato and carrot composition, original logo, two-line headline, supporting copy and two rounded actions. The ingredients and each theme's logo are vector contours traced directly from the approved mockups, rather than substituted icons. The SVG sources are bundled alongside the native Canvas geometry in `apps/mobile/lib/features/auth/welcome/artwork.dart`.

Reference layout is 390 logical points wide, with a 44-point status-bar inset and a 34-point home-indicator inset. Native status bars and safe areas remain controlled by the device. Other screen sizes adapt proportionally; increased text sizes and longer translations scroll rather than clip. Only the welcome page receives this visual treatment. Existing sign-in and registration actions and global app typography are preserved.

The focused `Welcome UI review` workflow renders the actual Italian Flutter screen in both themes, exercises the two actions, and checks all six locales on a small screen at 160% text scaling. Its `welcome-ui-review` artifact contains the rendered PNGs and formatted source files. The full repository CI additionally exercises existing authentication journeys.
