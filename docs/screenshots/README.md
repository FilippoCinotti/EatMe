# Real Flutter screenshot gallery

These are application renders, not supplied mockups. Source: `bf02052411ce68566e546a67746ff9d8bfd1fcdf`, [CI render run](https://github.com/FilippoCinotti/EatMe/actions/runs/34778268952). The subsequent formatter/documentation checkpoint does not alter the rendered layout. Test-only fixtures isolate demonstration accounts, quantities and package dates from production. Food imagery is illustrative and restricted to the bundled catalog. The CI PNG originals are 390 × 844; these WebP copies preserve their dimensions. Fonts are bundled with the application; see the [design notes](../product/visual-design.md) for font loading and provenance.

| Screen | Light | Dark |
| --- | --- | --- |
| ChefTable | <img src="chef-light.webp" width="260" alt="ChefTable, light theme, actual Flutter render" /> | <img src="chef-dark.webp" width="260" alt="ChefTable, dark theme, actual Flutter render" /> |
| Fridge | <img src="fridge-light.webp" width="260" alt="Fridge, light theme, actual Flutter render" /> | <img src="fridge-dark.webp" width="260" alt="Fridge, dark theme, actual Flutter render" /> |
| HealthyFood | <img src="healthy-food-light.webp" width="260" alt="HealthyFood, light theme, actual Flutter render" /> | <img src="healthy-food-dark.webp" width="260" alt="HealthyFood, dark theme, actual Flutter render" /> |
| Profile | <img src="profile-light.webp" width="260" alt="Profile, light theme, actual Flutter render" /> | <img src="profile-dark.webp" width="260" alt="Profile, dark theme, actual Flutter render" /> |
| Welcome | <img src="welcome-light.webp" width="260" alt="Welcome, light theme, actual Flutter render" /> | <img src="welcome-dark.webp" width="260" alt="Welcome, dark theme, actual Flutter render" /> |
| Login | <img src="login-light.webp" width="260" alt="Login, light theme, actual Flutter render" /> | <img src="login-dark.webp" width="260" alt="Login, dark theme, actual Flutter render" /> |
| Recipe detail | <img src="recipe-light.webp" width="260" alt="Recipe detail, light theme, actual Flutter render" /> | <img src="recipe-dark.webp" width="260" alt="Recipe detail, dark theme, actual Flutter render" /> |
| Diet and health | <img src="diet-health-light.webp" width="260" alt="Diet and health, light theme, actual Flutter render" /> | <img src="diet-health-dark.webp" width="260" alt="Diet and health, dark theme, actual Flutter render" /> |
| Preferences | <img src="preferences-light.webp" width="260" alt="Preferences, light theme, actual Flutter render" /> | <img src="preferences-dark.webp" width="260" alt="Preferences, dark theme, actual Flutter render" /> |
| Notifications | <img src="notifications-light.webp" width="260" alt="Notifications, light theme, actual Flutter render" /> | <img src="notifications-dark.webp" width="260" alt="Notifications, dark theme, actual Flutter render" /> |
| Household | <img src="household-light.webp" width="260" alt="Household, light theme, actual Flutter render" /> | <img src="household-dark.webp" width="260" alt="Household, dark theme, actual Flutter render" /> |
| Privacy and data | <img src="privacy-light.webp" width="260" alt="Privacy and data, light theme, actual Flutter render" /> | <img src="privacy-dark.webp" width="260" alt="Privacy and data, dark theme, actual Flutter render" /> |
| Recipe filters | <img src="filters-light.webp" width="260" alt="Recipe filters, light theme, actual Flutter render" /> | <img src="filters-dark.webp" width="260" alt="Recipe filters, dark theme, actual Flutter render" /> |
| Add ingredient | <img src="add-ingredient-light.webp" width="260" alt="Add ingredient, light theme, actual Flutter render" /> | <img src="add-ingredient-dark.webp" width="260" alt="Add ingredient, dark theme, actual Flutter render" /> |
| Custom food | <img src="custom-food-light.webp" width="260" alt="Custom food, light theme, actual Flutter render" /> | <img src="custom-food-dark.webp" width="260" alt="Custom food, dark theme, actual Flutter render" /> |
| Personal goals | <img src="wellbeing-light.webp" width="260" alt="Personal goals, light theme, actual Flutter render" /> | <img src="wellbeing-dark.webp" width="260" alt="Personal goals, dark theme, actual Flutter render" /> |

Regenerate with the repository-pinned Flutter SDK:

```bash
cd apps/mobile
flutter test test/visual_reference_test.dart test/premium_journeys_test.dart test/reference_features_test.dart
```

Renders are written to `build/screenshots/`. Tests also exercise larger text and compact Italian layouts; screenshots show the 1.0 text-scale fixture. CI retains native Android/iOS debug artifacts separately. These images are interface validation assets, not certified store-release screenshots.
