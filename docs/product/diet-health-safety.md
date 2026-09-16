# Diet & Health safety model

## Direct control

Diet & Health is the canonical self-service control centre. A user can combine every published profile, choose one primary profile, set strictness per profile, record allergies and intolerances, add explicit food exclusions, and select the unknown-ingredient policy. Changes are versioned through the existing profile API and immediately refresh recommendations.

The supported self-declared profiles in rule-set version 1 are Balanced, Mediterranean, Vegetarian, Vegan, Pescatarian, High protein, Gluten free, Celiac and RAD. Celiac and RAD require an explicit acknowledgement because they are health-related settings; neither requires a document, prescription, administrator approval or diagnosis. The acknowledgement is consent to product filtering, not medical advice.

RAD in EatMe is a deliberately narrow product profile, not a complete therapeutic protocol. Version 1 prefers catalogued vegetables and legumes and hard-blocks the catalogued wheat-pasta item. EatMe does not infer a diagnosis or make a treatment, inflammation or nutrition claim. The rule must remain versioned and must be reviewed before its scope is expanded.

## One authoritative hierarchy

All compatibility surfaces call the same engine. Evaluation order is:

1. canonical ingredient status;
2. allergens and may-contain declarations;
3. intolerances;
4. explicit user exclusions;
5. published, effective profile rules;
6. lifestyle preference matches;
7. inventory, expiry, speed, budget and other ranking signals.

Hard rules filter candidates before any ChefTable mode or score is applied. `quick`, `use_soon`, `no_shopping`, `health_first` and `plant_based` cannot restore a rejected candidate. A flexible lifestyle profile may produce a visible warning, but it never weakens an allergen, intolerance, clinical-profile hard rule, explicit exclusion or unknown ingredient.

## Multiple profiles and conflicts

Assignments carry their own `flexible`, `standard` or `strict` setting. `primary_diet` is presentation context only and never changes the safety intersection. When one active rule explicitly allows the same food, group or allergen that another active hard rule excludes, profile saving fails with `diet_profile_conflict` and structured details naming both rule owners. Hard exclusion wins at runtime; incompatible configuration is not silently accepted.

## Unknown ingredients

`strict` is the default. It blocks an unresolved canonical ingredient. `review` keeps an import or review flow incomplete until the user maps or explicitly reviews it; it never converts unknown into compatible and never permits a “safe” claim. ChefTable only ranks recipes whose ingredients are canonical.

## Explainability

ChefTable displays the active profile set, primary profile ordering, explicit safety-rule count and unknown policy. Every ranked recommendation has already passed canonical, allergy, intolerance, explicit-exclusion and published-profile filters. The UI therefore says “no known conflicts with active hard-safety rules,” never “universally safe.” Social imports retain their mandatory review, mapping, compatibility, curated substitution and full re-check sequence.
