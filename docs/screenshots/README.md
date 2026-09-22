# Production screenshot baseline

The committed gallery contains real renders from the Flutter application and the production Guest RSVP application. Fixture content exists only inside test or `SCREENSHOT_MODE=1` routes and is unavailable in ordinary production execution.

## Current inventory

- Mobile: 116 English renders at 390 × 844 (58 screens/states, Light and Dark), including the Guilty Pleasure sheet and active states.
- Guest Web: 27 English renders covering the full RSVP flow in Light and Dark plus the desktop invitation landing page.
- Localization smoke: five Guest RSVP review renders covering Italian, Spanish, French, German and Simplified Chinese.
- Total baseline: 148 real renders.
- Machine-readable inventory: `manifest.json`.
- Coverage policy: `required_screens.json`.

The coverage gate passes only when every required render exists. It also compares the route policy to `apps/mobile/lib/main.dart`, so a newly added production route must be classified for screenshot coverage.

## Layout

```text
docs/screenshots/mobile/en/light/
docs/screenshots/mobile/en/dark/
docs/screenshots/guest/en/light/
docs/screenshots/guest/en/dark/
docs/screenshots/localization/
```

Each manifest row records the screen ID, product route or deterministic fixture, platform, theme, locale, state and generated filename. The release workflow replaces the source commit with the exact reviewed SHA and records the render date.

## Regenerate

From the repository root:

```bash
cd apps/mobile
flutter test
cd ../..
python3 scripts/collect_screenshots.py apps/mobile/build/screenshots

cd apps/guest
npm ci --ignore-scripts
npm run build
npx playwright install chromium
SCREENSHOT_MODE=1 PORT=3000 npm start -- --hostname 127.0.0.1
# In another shell:
npm run screenshots
cd ../..

python3 scripts/build_screenshot_manifest.py --commit "$(git rev-parse HEAD)"
python3 scripts/check_screenshot_coverage.py --require-files
```

The native iOS launch screen is also captured separately during the cold-launch device acceptance pass. `native-splash-reference-*` is a Flutter-rendered visual reference and is not a substitute for that native evidence.

## Release quality checks

Review the full gallery for overflow, clipping, safe areas, missing assets, untranslated copy, fixture leakage, theme contrast and large-text behavior. CI exercises core pages at 1.6× text scale; the TestFlight acceptance pass additionally covers compact and large iPhones and a non-catastrophic larger layout.
