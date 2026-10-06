# Recipe, inventory and profile fixes (PR 69)

- Recipe planning opens a dedicated planner with the requested recipe, including private recipes. Family members initialize diner selection and servings; explicit later choices are retained for the screen. Existing member consent and dietary checks remain enforced.
- Planner actions share their row height and selected diners remain visible below it.
- Recipe sharing uses the existing header icon. Recipe and food actions use accessible icons; food management uses a compact toolbar.
- Leftovers reuse the source recipe photo inside an illustrative lunchbox frame, without a paid image call. A missing photo keeps the existing fallback.
- Fridge leftovers receive a proposed use date three days after cooking. Moving stock never resets that date. Frozen items do not receive an invented WHO storage duration. User dates remain editable.
- Import review uses localized catalog names and photos, expandable storage details and one confirmation for the list. Changes invalidate confirmation. Missing identification, quantity or confidence below 85% is highlighted.
- Import date estimates use existing catalog shelf-life data from the editable purchase date. Package dates take precedence; estimated dates are marked. Quantity extraction uses visible evidence; mismatched units discard the estimate instead of relabeling it. Purchase date is saved with inventory metadata.
- Diet & Health uses short descriptions and colored selection cards. Cooking skills use illustrated choices, cooking time a rabbit-to-turtle slider in 30-minute increments, and cuisines predefined multiple selection.
- Wellbeing uses two-column goal cards, a one-tap daily check-in and icon controls. The existing versioned API prevents duplicate day counts and persists updates.
- Impact already calculates from the first eligible inventory use; the 100-meal limit is a reporting window, not a threshold. Copy and a regression assertion make that distinction explicit.
- All new and changed strings are translated into en, it, es, fr, de and zh-Hans. Dates use the app locale.

## Storage sources and limits

WHO, *Five keys to safer food manual*, p. 19:
https://iris.who.int/bitstream/handle/10665/43546/9789241594639_eng.pdf?sequence=1

The manual recommends refrigerating promptly, below 5 °C, not leaving cooked food at room temperature longer than two hours, and keeping refrigerated leftovers no longer than three days. The proposed date assumes these conditions; the app cannot observe actual handling. It is not a safety certification. No generalized freezer duration is attributed to WHO.

Existing ingredient shelf-life estimates are catalog heuristics, not WHO product expiry rules, and do not override a manufacturer date. Carbon and monetary estimates remain based on available factors and recorded cost, with coverage exposed.

## Validation

Local: API unit suite, Ruff, repository contracts, six-language localization contract, Dart parsing/formatting, whitespace diff checks.
Flutter runtime checks: existing PR CI on Linux and macOS. Local dependency bootstrap was stopped after automatic review blocked a metadata-endpoint request; no retry or metadata access is required for PR CI.
