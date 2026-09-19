# Food Decision Engine information architecture

EatMe’s consumer promise is **“Your recipes. Your fridge. Your diet. One decision.”** The product loop is:

1. **Decide** — ChefTable ranks only compatible candidates and explains one or two real reasons.
2. **Plan** — the user places a reviewed recipe into a week or previews an EatMe+ generated week before accepting it.
3. **Shop if needed** — generated requirements subtract usable known inventory; manual shopping remains available to Free users.
4. **Adapt** — Social Import and recipe detail use the authoritative canonical mapping and Diet-Fit engine.
5. **Cook** — Cook Mode keeps the current recipe and step in focus.
6. **Update** — the user reviews estimated ingredient consumption or purchased items before inventory changes.

## Four primary jobs

| Destination | User question | Primary responsibility |
| --- | --- | --- |
| ChefTable | What should I eat? | Explained, context-aware decision and recipe entry points |
| Fridge | What do I have? | Low-effort inventory, Use Soon, recognition review and leftovers |
| Plan | What am I eating next? | Week, meal slots, Smart Plan preview and Shopping List |
| Profile | How should EatMe adapt to me? | Diet & Health, household, preferences, privacy and EatMe+ |

HealthyFood is no longer a primary destination. Its useful compatibility, nutrition and evidence capabilities remain available from recipe detail, discovery and Profile. The legacy route remains temporarily available for deep-link compatibility.

## State and routing

Plan and Shopping List share the Plan destination. `/shopping` is a compatibility redirect to `/plan/shopping`; it is not a fifth primary tab. Diet & Health is one hub with section editors rather than a route for every result state. Diet-Fit compatible, review, conflict and unknown outcomes remain states of shared components.

## Data and migration boundaries

The current profile schema is extended through optional settings with fail-closed defaults. Existing diets, allergies, intolerances, explicit exclusions and unknown policy are preserved. Profiles created before trace handling became configurable default to `block`, preserving the previous safety behavior.

Smart Plan preview is deliberately non-persistent until the user accepts it. Generated Shopping List and Smart Planning are server-authorized capabilities; basic manual Plan and Shopping remain Free. Shopping-to-Fridge and post-cooking stock updates require explicit confirmation.

## Intentional limitations

- Smart Plan supports review, swap and removal before acceptance. Per-meal lock and server-side single-meal regeneration remain a follow-up; the UI does not claim they exist.
- HealthyFood redistribution is evolutionary. The legacy route remains while evidence and long-tail discovery surfaces migrate.
- Provider-backed receipt/photo recognition remains dependent on configured providers and explicit review. No production recognition result is fabricated.
- Medical awareness settings do not create clinical nutrient targets. Unsupported therapeutic profiles remain unavailable or “needs review.”
