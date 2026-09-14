# EatMe visual design system

## Direction and hierarchy

EatMe is a food companion: eat what you have, choose what fits you, waste less. The approved September 13 premium references guide the new presentation. Only the redesigned side of comparison boards is used. ChefTable answers what to cook, Fridge what to use, HealthyFood what to explore, and Profile how the app is personalized. The lifestyle line is “Good food today. A healthier tomorrow.” All visible copy is localized into English and Italian.

The presentation reuses the production Riverpod, Supabase, API, offline and transaction architecture. Reference illustrations never supply account, clinical, quantity, expiry, subscription or ranking data. There are no invented benefit badges, nutrition scores, recognition confidence values or emissions claims. Unknown catalog imagery uses a neutral symbol. Saved restrictions and assessment warnings remain authoritative.

## Tokens

| Token | Light | Dark |
| --- | --- | --- |
| Page | `#F8F9F5` | `#101413` |
| Surface | warm white | `#1B211E` |
| Secondary surface | `#EDF1EB` | `#242C27` |
| Accent | `#2E7346` | `#94D9AA` |
| Text | `#17221B` | `#F0F3EE` |
| Secondary text | `#626D66` | `#BAC4BD` |

The shared spacing scale is 4, 8, 12, 16, 20, 24, 32, 40 and 48 logical pixels. Inputs and compact actions use 14–18 pixel corners, photo cards 23–28, panels 26 and floating navigation 32. Pills use stadium geometry. Surface tone, imagery and typography carry hierarchy; borders are reserved for focus and the quiet glass highlight.

`theme.dart` owns shared theme values. `premium.dart`, `recipe_hero.dart`, `food_image.dart` and `widgets.dart` own composition primitives: EditorialHeader, EatMeWordmark, SearchPill, RoundAction, HeroRecipeCard, FoodPhotoCard, StatusBadge, CategoryTile, AdaptivePhotoGrid, HorizontalFoodRail, InformationPanel, GlassSurface, SettingsGroup, SettingRow, EatMeSelectionRow, EatMeToggleRow, EatMeTabStrip, ShortcutTile and CompactShortcut. Secondary navigation shares EatMeAppBar. InformationPanel paints its background on Material so child controls retain visible ink feedback.

## Brand and iconography

The production wordmark uses an original two-leaf EatMe mark implemented as a Flutter vector painter in `design_system/brand.dart`. The same geometry is retained in `assets/brand/eatme-mark.svg` for documentation and non-Flutter use. It is not assembled from a generic interface icon and adapts to the active theme color without raster assets.

Visible product iconography uses a curated subset of Lucide 1.8.0 geometry. Lucide was selected for its consistent rounded joins, restrained outline construction and cross-platform optical weight. EatMe bundles only the required paths and renders them through `EatMeGlyph`, `EatMeIcon` and `EatMeIconButton`; screens do not depend on a third-party Flutter icon package and the application does not ship an unnecessary full icon font. The original ISC license and the applicable Feather MIT attribution are retained in `assets/icons/LICENSE_LUCIDE.txt`.

Primary navigation, page actions, profile groups, filtering, food actions and status controls use the EatMe abstraction. Material widgets may remain underneath for semantics, focus, ink response and platform behavior, but their default glyphs and visible navigation treatment are not the product's visual language. Food-image fallbacks remain neutral and never borrow a demonstration photograph for unknown content.

## Typography and font provenance

EatMeDisplay is a renamed Latin subset of STIX General, bundled from the Matplotlib distribution under the SIL Open Font License. EatMeSans is a renamed Latin subset of DejaVu Sans, bundled under its included font license. Original license texts are retained beside the font files in `apps/mobile/assets/fonts/`. No runtime font download is required. The subsets cover English, Italian and Latin accents, punctuation and the euro sign.

Display headings use an editorial serif treatment at 38 logical pixels, section headings 24–28, body text 16 and navigation labels 11. Body text remains regular, with restrained tracking. Production resolves the bundled regular and bold weights. Widget render tests explicitly load the bundled regular faces and allow Flutter to synthesize requested weights; this avoids loading both faces as the same dynamic font weight in FontLoader. Native applications resolve the pubspec's explicit 400/700 faces.

## Composition

- ChefTable leads with search and a photographed recommendation. The explanation uses actual ingredient availability, preparation time and use-soon IDs. The filter sheet preserves exact recommendation mode values, including the existing plant-based mode. Favorite state is retrieved, never assumed. Cooking opens the recipe and safety preview before the transaction flow.
- Fridge places expiring stock before an adaptive inventory grid. Each card retains recorded quantity, location, package-date semantics and access to the existing batch operations. Scan, barcode, manual catalog search, custom food and leftover routes remain available.
- HealthyFood uses real catalog categories and photographic exploration. Favorites remain personal state. It does not label catalog ordering as clinical personalization. The assessment keeps warnings visible across Information, Nutrition and For you.
- Profile groups diet and health, household, preferences and notifications above kitchen shortcuts. The dietary summary reads saved restrictions; editing still uses the existing consent workflow. Privacy, subscriptions, sync, evidence, insights, activity and logout remain accessible.
- Recipe detail is photograph-led with wrapping sections, real availability and servings. Favorite/share and optional tools use progressive disclosure. Start cooking retains preview and offline guards.
- Welcome, login, registration, reset, scanner/import, add-food, shopping, planner, household and other secondary routes share typography, surfaces and controls. OAuth buttons retain real provider configuration and production legal requirements.

## Glass, motion and dark mode

Four destinations remain: ChefTable, Fridge, HealthyFood and Profile. `EatMeNavigationBar` is a bespoke destination layout rather than a styled Material NavigationBar. The bar is detached with horizontal and bottom margins, a true 20-pixel backdrop blur, restrained highlight and soft shadow. Each selected destination receives a quiet green inner capsule, stronger label weight and a short scale/opacity transition. Dark glass uses a darker, more opaque surface rather than an inverted light effect. High-contrast mode removes transparency and blur. Navigation selection respects the platform's reduce-motion preference.

## Responsive behavior and accessibility

Content is bounded to a readable maximum width within the existing hinge-safe display region. The inventory/catalog grid collapses to one column for narrow widths or larger text. Photo rails grow their card width with text size and scroll horizontally. Labels wrap, filters use content-sized controls, dropdowns expand within their available width, and secondary titles retain complete semantics even when visually ellipsized. Page content includes bottom clearance for the floating navigation and keyboard-aware sheets preserve all fields/actions. Existing autofill hints and password visibility remain intact.

Semantics, explicit tooltips, text-based warnings and touch targets accompany iconography. Unknown dates retain their recorded unknown status; date types are never silently converted into shelf-life predictions. Safety warnings use text and icons, not color alone.

## Real render review

`visual_reference_test.dart` renders all four destinations in both themes and checks 1.6× text. `premium_journeys_test.dart` renders welcome/login, preferences, notifications, household, privacy, diet and health, recipe detail, filters and add-ingredient flows. It also exercises scrolling, compact Italian layouts and persistent allergen warnings. `reference_features_test.dart` retains custom-food, scanning and wellbeing coverage. Existing hinge, API and transaction tests remain enabled.

Run the mobile tests with the repository-pinned Flutter SDK and `FLUTTER_ROOT`. PNGs are emitted under `apps/mobile/build/screenshots/`; reviewed copies in `docs/screenshots/` are WebP at the original dimensions. Supplied boards are never published as application screenshots. CI artifacts additionally retain native build outputs and the full render set.

The review loop caught and corrected background/ink containment in grouped settings and a large-text dropdown overflow. Font weight loading was corrected after inspecting real renders. See `premium-redesign-reconciliation.md` and `verification.md` for the tested baselines and CI outcomes.

## Illustrative asset provenance

Asset: `apps/mobile/assets/images/food-atlas.webp`. Created with the built-in image generation tool, not the CLI. It is AI-generated illustrative food photography, not a photograph of a user's meal or evidence of recognition accuracy. The generated source was resized and encoded as WebP for efficient mobile delivery; Flutter selects its source region at rendering time. The mapping is restricted to the sixteen bundled demonstration catalog IDs.

Prompt used:

> One photographic food texture atlas for a Flutter cooking application: a square image with a precise 4 × 4 grid of equal cells, no gutters, borders, text, labels, UI or watermark. Center each subject on a warm ivory studio background, with soft natural side lighting and realistic food textures. Row 1: chickpea and tomato bowl with olive oil; zucchini and spinach pasta with olive oil; tomato, chickpea and feta salad with olive oil; spinach and chickpea rice with olive oil. Row 2: tomatoes on the vine; zucchini; spinach leaves; cooked chickpeas. Row 3: dry rice; dry wheat pasta; unlabeled olive oil bottle; feta. Row 4: raw chicken breast on a plate; shelled peanuts; brown eggs; unlabeled milk bottle. Keep each subject within its own cell, and do not add garnishes or extra ingredients to the meals.

The generated atlas is bundled for reproducible offline rendering. Screenshots in the README must come from the Flutter test renders, not from the reference boards or generated UI mockups.
