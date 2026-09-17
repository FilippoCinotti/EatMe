# Free and EatMe+

EatMe has exactly two tiers. RevenueCat and the platform stores remain authoritative for paid status and localized prices. UI code reads named server capabilities; it does not inspect product identifiers or scatter `premium` conditionals through feature widgets.

| Capability | Free | EatMe+ |
| --- | --- | --- |
| Account, recipe library and manual recipes | Included | Included |
| ChefTable basic recommendations | Included | Included |
| Manual Fridge, Plan and Shopping List | Included | Included |
| Dinner events, guests and RSVP links | Included | Included |
| Dinner Diet-Fit and essential conflict visibility | Always included | Always included |
| Dinner generated Shopping List | Contextual upgrade | Included |
| Dinner timeline, adaptive servings and Meal Memory | Included | Included |
| Diet & Health configuration | Included | Included |
| Essential allergen/conflict visibility | Always included | Always included |
| Social Recipe Import | Configurable lifetime allowance (default 3) | Unlimited |
| Smart Diet-Fit and reviewed mapping | Limited smart journey; warnings never hidden | Advanced/unlimited |
| Reviewed substitutions | Limited | Advanced |
| Generated Shopping List | Contextual upgrade | Included |
| Smart Meal Planning preview | Contextual upgrade | Included |
| Receipt and advanced photo recognition | Provider/configuration dependent | Capability-ready |
| Household profiles, advanced timing, premium insights | Basic/current features remain usable | Capability-ready |

The default Smart Import allowance is configured by `FREE_SMART_IMPORT_LIMIT`; it is not hard-coded in Flutter. A counter is consumed only after extraction succeeds. Private, deleted, unsupported or failed imports do not consume an experience.

The entitlement response exposes a tier, named capabilities, limits, usage and remaining counts. Paid status is verified server-side from RevenueCat and cached briefly. Safety-critical information uses the independent `canSeeSafetyWarnings` capability, which is always true. Dinner invitations, responses and Diet-Fit safety results never depend on a paid entitlement; only generated shopping reuses `canUseGeneratedShopping`.

## Pricing and trials

Production displays `StoreProduct.priceString`. Annual savings are calculated only when both monthly and annual localized store products are available and the annual price is actually lower. The approved €4.99/month and €49.99/year values are screenshot fixtures only; they are not universal application copy.

The UI does not claim a trial unless the store offering exposes one. The current generic CTA is “Try EatMe+”. Restore purchases, manage subscription, Terms and Privacy remain accessible where configured.

## Contextual paywalls

Paywalls appear at the attempted premium action (for example Smart Planning, generated Shopping or an exhausted Smart Import allowance), describe the relevant benefit and always offer “Not now”. First launch is never paywalled, manual alternatives remain usable and allergen warnings are never blocked.
