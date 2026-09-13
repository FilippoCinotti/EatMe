# Visual design reference

The September 2026 redesign follows the owner's supplied light/dark EatMe boards: warm white and charcoal surfaces, leafy green accents, photographic food cards, rounded compact controls and an elevated translucent navigation bar. The four primary destinations remain ChefTable, Fridge, HealthyFood and Profile. Search, shopping and planning stay connected secondary workflows.

## Implementation

- `apps/mobile/lib/design_system/theme.dart` owns shared color, typography, card, input, button and navigation tokens.
- `food_image.dart` draws a cell from a single cached image atlas. There are no network image requests and no additional image package. Unknown/private IDs receive a neutral icon instead of an unrelated meal photograph.
- ChefTable prioritizes nearby recorded food dates and a photographed recipe. Fridge uses product cards; HealthyFood uses category filters and a responsive photo grid. At larger text sizes the grid becomes one column.
- Recipe detail, cooking, shopping, library and planner views reuse the same imagery and controls. Existing API commands, consent checks, stock transactions and clinical review gates are unchanged.
- The visual tests exercise all four main screens in both themes at 390 × 844, at 100% and 160% text scaling. Existing tests retain hinge-safe navigation and transactional workflow coverage.

The supplied boards are visual references, not verified product data. Nutritional scores, recognition confidence, automatic expiry estimates, waste/CO₂ savings and clinical claims shown in them are not fabricated in the application. Actual quantities, dates and compatibility notices retain their existing source and safety semantics.

## Illustrative asset provenance

Asset: `apps/mobile/assets/images/food-atlas.webp`. Created with the built-in image generation tool, not the CLI. It is AI-generated illustrative food photography, not a photograph of a user's meal or evidence of recognition accuracy. The generated source was resized and encoded as WebP for efficient mobile delivery; Flutter selects its source region at rendering time. The mapping is restricted to the sixteen bundled demonstration catalog IDs.

Prompt used:

> One photographic food texture atlas for a Flutter cooking application: a square image with a precise 4 × 4 grid of equal cells, no gutters, borders, text, labels, UI or watermark. Center each subject on a warm ivory studio background, with soft natural side lighting and realistic food textures. Row 1: chickpea and tomato bowl with olive oil; zucchini and spinach pasta with olive oil; tomato, chickpea and feta salad with olive oil; spinach and chickpea rice with olive oil. Row 2: tomatoes on the vine; zucchini; spinach leaves; cooked chickpeas. Row 3: dry rice; dry wheat pasta; unlabeled olive oil bottle; feta. Row 4: raw chicken breast on a plate; shelled peanuts; brown eggs; unlabeled milk bottle. Keep each subject within its own cell, and do not add garnishes or extra ingredients to the meals.

The generated atlas is bundled for reproducible offline rendering. Screenshots in the README must come from the Flutter test renders, not from the reference boards or generated UI mockups.
