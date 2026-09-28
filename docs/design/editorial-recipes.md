# ChefTable and recipe editorial refresh

The discovery, recipe and cooking journeys share a local `RecipeEditorial` theme. The wordmark, bundled fonts, global theme and unrelated screens retain their existing identity.

- Display titles 24, section titles 22, recipe row titles 17, actions 15, supporting text 13–15 logical pixels. User text scaling remains enabled.
- Buttons have at least 48 logical pixels of height. Action rows stack on small screens or with large text; sticky recipe/cooking footers reserve their actual height and safe area.
- Search precedes recommendation modes. Hero actions stay with the recipe. Profile restrictions remain reachable; all recommendation modes, favorites, tools and expiry navigation are retained.
- Recipe descriptions expand, source attribution links remain, portions and diners still reload the preview. Tabs stay on one line and scroll horizontally. Compatibility notes, shortages, unknown quantities, substitutions and nutrition provenance retain their data-driven behavior.
- Cooking keeps real steps and suggested timers. Custom durations override the suggestion for that step; active timers continue across step navigation. Empty instructions are handled explicitly. Finishing still enters consumption/leftover confirmation and does not mutate inventory by itself.
- Ingredient photo mosaics are removed. Remote recipe photography remains the first choice; unmapped recipes have a neutral placeholder instead of an unrelated dish.

## Image provenance

`assets/images/uova-marshmallow.png` is an AI-generated illustrative photo created for EatMe, using the verified catalog's ingredients, preparation and image brief. It is mapped only to recipe `b6e34b78-ba48-558f-bcc8-43cf54c9131c`. It is not an image from the credited recipe publisher. The original recipe/source attribution is preserved separately. Existing remote or user-owned photos take priority.

## Verification

`test/editorial_recipes_test.dart` covers 390px and 320px/1.6x text layouts, persistent recipe actions, one-line tabs, custom timer navigation, confirmation and empty steps. It exports Italian discovery/recipe screenshots and cooking screenshots into `build/screenshots`; the existing CI publishes them in `interface-review-*` artifacts.

Local Dart formatting, JSON/localization and repository checks are available. Dependency resolution in this workspace was blocked by automatic review after an unexpected cloud metadata request; no bypass or retry is used. Flutter analysis, widget execution and build evidence must come from the existing GitHub CI before this change is treated as verified for release.
