# Diet & Health safety model

## Direct control

Diet & Health is the canonical self-service control centre. Its default presentation is a compact hub with current-state summaries for eating style, allergies, intolerances and sensitivities, medical settings, therapeutic protocols, religious/ethical preferences, meal timing, explicit exclusions and unknown ingredients. Each section opens a focused editor. Changes are versioned through the existing profile API and immediately refresh recommendations.

Published lifestyle profiles include Omnivore, Balanced, Mediterranean, Vegetarian, Vegan, Pescatarian, Flexitarian, Plant-forward, Low-carb preference, Low-fat preference, High protein and Whole-food focused. Profiles without sufficient nutrient or processing data record a preference without inventing a threshold. Gluten free, Celiac and RAD use published rules; health-related settings require explicit acknowledgement. The acknowledgement is consent to product filtering, not medical advice.

RAD in EatMe is a deliberately narrow product profile, not a complete therapeutic protocol. Version 1 prefers catalogued vegetables and legumes and hard-blocks the catalogued wheat-pasta item. EatMe does not infer a diagnosis or make a treatment, inflammation or nutrition claim. The rule must remain versioned and must be reviewed before its scope is expanded.

## One authoritative hierarchy

All compatibility surfaces call the same engine. Evaluation order is:

1. canonical ingredient status;
2. allergens and may-contain declarations;
3. intolerances;
4. explicit user exclusions;
5. medical awareness and published medical rules;
6. therapeutic protocols;
7. religious hard exclusions;
8. eating-style rules;
9. lifestyle preference matches;
10. inventory, expiry, speed, budget and other ranking signals.

Hard rules filter candidates before any ChefTable mode or score is applied. `quick`, `use_soon`, `no_shopping`, `health_first` and `plant_based` cannot restore a rejected candidate. A flexible lifestyle profile may produce a visible warning, but it never weakens an allergen, intolerance, clinical-profile hard rule, explicit exclusion or unknown ingredient.

## Multiple profiles and conflicts

Assignments carry their own `flexible`, `standard` or `strict` setting. `primary_diet` is presentation context only and never changes the safety intersection. When one active rule explicitly allows the same food, group or allergen that another active hard rule excludes, profile saving fails with `diet_profile_conflict` and structured details naming both rule owners. Hard exclusion wins at runtime; incompatible configuration is not silently accepted.

## Unknown ingredients

`strict` is the default. It blocks an unresolved canonical ingredient. `review` keeps an import or review flow incomplete until the user maps or explicitly reviews it; it never converts unknown into compatible and never permits a “safe” claim. ChefTable only ranks recipes whose ingredients are canonical.

## Structured settings and uncertainty

Allergies, intolerances and user-declared sensitivities are stored as independent dimensions. Wheat allergy, celiac disease and a gluten-free preference are not interchangeable. Trace handling is explicit (`ignore`, `review`, `block`); legacy profiles default to `block` so migration cannot weaken prior safety.

Medical awareness includes IBS, diabetes, prediabetes, renal restriction, hypertension, hyperlipidemia, gout, GERD, PKU and clinician-defined settings. These values create a review warning; they do not generate therapeutic targets. Low-FODMAP, renal and diabetes-specific protocols remain unavailable until evaluable, serving-dependent or clinician-configured data exists.

Halal and Kosher selections generate certification-unknown notes unless authoritative certification data exists. Ingredient inference never becomes a certification claim. Hard religious exclusions such as no shellfish remain distinct from certification.

Meal timing stores a standard or time-restricted window. It provides planning context only and does not make a health claim.

## Explainability

ChefTable displays the active profile set, primary profile ordering, explicit safety-rule count and unknown policy. Every ranked recommendation has already passed canonical, allergy, intolerance, explicit-exclusion and published-profile filters. The UI therefore says “no known conflicts with active hard-safety rules,” never “universally safe.” Social imports retain their mandatory review, mapping, compatibility, curated substitution and full re-check sequence.
