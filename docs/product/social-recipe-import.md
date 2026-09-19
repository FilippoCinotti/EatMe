# Social recipe import and Smart Diet-Fit

## Product sequence

The approved social-import storyboards define both the visual hierarchy and the interaction order. EatMe implements the sequence below without saving a recipe implicitly:

1. Recipe Library (or the secondary ChefTable kitchen-tools action)
2. Import Recipe
3. Read public YouTube, Instagram or recipe-page metadata
4. Editable recipe review
5. Canonical ingredient mapping
6. Complete diet and safety assessment
7. Inventory coverage
8. Optional curated substitutions selected by the user
9. Complete compatibility and inventory re-check
10. Save to Library or Cook Now

The draft remains local UI state until the last action. A cancelled extraction or compatibility check does not create content. Cook Now saves the reviewed private recipe first, then enters the existing cooking preview, which independently enforces the complete current safety rules.

## Public-source extraction

`POST /api/v1/recipes/import-url` accepts only HTTPS URLs for public YouTube videos/shorts, public Instagram posts/reels/TV items and ordinary public recipe pages. The request requires `private_use_confirmed: true`. The backend uses the existing DNS-pinned, redirect-limited, response-size-limited HTTPS transport. It reads public schema.org Recipe JSON-LD and restrained Open Graph metadata; it does not authenticate to a provider, bypass access controls or use a provider-specific scraping session.

The extractor returns only fields present in the public response:

- title, creator and thumbnail URL when exposed;
- ingredient source lines;
- steps;
- servings and ISO-duration minutes;
- platform, original URL and import timestamp;
- `missing_fields` and whether canonical mapping needs review.

Missing fields stay unknown. A partial result continues to the mandatory editor with the message that it must be completed. Unsupported, private, deleted, unreachable, rate-limited and provider-unavailable responses retain separate error codes. The original URL remains attached to every saved imported/adapted recipe and is visible from the final recipe.

## Ingredient normalization

Imported text is matched against exact normalized aliases from the current EatMe catalog. Quantity conversion is deterministic and limited to compatible mass, volume and whole-piece units.

| Status | Meaning | Compatibility behavior |
| --- | --- | --- |
| `matched` | Catalog food, quantity and unit are known and user-confirmed | Included in the assessment |
| `needs_review` | A plausible catalog food exists but quantity, unit or edited source text needs confirmation | Excluded; assessment stays incomplete |
| `unknown` | No reliable catalog match exists | Excluded; assessment stays incomplete |

Editing an ingredient name invalidates automatic confirmation. The user can confirm a proposal, select another canonical food, delete the row, add a missing row or deliberately leave it unresolved. EatMe never claims that a recipe fits while unresolved rows remain.

## Compatibility and inventory

`POST /api/v1/recipes/import-review` calls the same versioned `compatibility` engine used by recommendations, food assessment and cooking. It preserves the existing precedence: allergens, intolerances, medical rules and explicit exclusions remain harder than diet or lifestyle preferences. The response classifies explainable reasons as `hard_safety`, `diet`, `lifestyle` or `unknown`; this classification does not replace or weaken the original reason code.

Inventory coverage uses only usable batches in the active household and the existing package-date semantics. It returns quantity-aware availability, missing food IDs and confirmed ingredients with a recorded date within two days. Coverage is visually secondary to safety status and is recalculated from the entire edited ingredient list after every substitution.

## Curated substitutions

Substitution candidates come from `services/api/eatme/substitutions.py`, a deliberately small, reviewable table. Each mapping records a culinary role and review version; it does not assert nutrition equivalence. Before a candidate is returned, it is checked as a canonical food against the user's current complete compatibility rules.

No candidate is auto-selected or auto-applied. The user selects or deselects alternatives and the app edits a private copy while preserving source provenance. A unit-changing substitution becomes `needs_review` with unknown quantity rather than silently reusing an incompatible measurement. After application, the backend reruns the full recipe assessment and inventory calculation. When no candidate passes, the UI explicitly says that no suitable substitution is currently available and offers manual mapping or saving with a persistent warning.

An imported recipe with known conflicts may be stored only after explicit acknowledgement. Unknown mappings or missing required recipe fields cannot be stored. Cooking remains blocked whenever the normal cooking preview reports incompatibility, even if a private recipe was previously saved with acknowledgement.

## Current provider limits

- Success depends on structured recipe information or parseable ingredient/method sections exposed publicly by the source.
- Provider captions without reliable recipe structure may produce a partial draft or “no recipe detected.”
- EatMe stores the source URL and textual fields needed for the private recipe. It retains a remote thumbnail URL only when the public metadata supplies HTTPS media; it does not claim ownership of source media.
- Import cancellation stops UI progression. The already-started read-only HTTP request may finish server-side, but it cannot save a recipe.
- The curated substitution table is intentionally incomplete. No generative model alone can add a clinically safe candidate.

## Verification coverage

API tests cover public YouTube, Instagram and recipe-page extraction, partial extraction, source failures, mapping states, allergens, intolerance, diets, inventory, substitutions, full re-check, provenance, acknowledgement, saving, reopening and cooking preview. Flutter tests cover the mandatory UI sequence, edit/delete/add review controls, no-save-before-confirmation, manual selection, substitution/re-check, provider failure recovery and camera permission failure. Real render tests emit every approved flow state in light and dark mode.
