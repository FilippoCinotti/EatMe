# EATME

## Ultimate Product, UX, AI, Backend, Mobile and GitHub Implementation Specification

You are acting as the complete senior product and engineering team responsible for designing, implementing, testing, documenting and preparing for release a production-grade consumer application called:

# EatMe

EatMe is a cross-platform mobile application for iOS and Android.

This document is the **single source of truth for the product**.

Your responsibility is NOT to create a mockup or partially functional demo.

Your responsibility is to build the foundation of a real commercial product, including:

- mobile application;
- backend;
- database;
- AI services;
- diet engine;
- nutrition engine;
- recommendation engine;
- food inventory;
- scientific evidence system;
- administration dashboard;
- automated tests;
- CI/CD;
- GitHub repository structure;
- privacy architecture;
- security;
- monitoring;
- documentation;
- deployment strategy;
- release preparation.

When specifications are ambiguous, make the simplest production-quality decision consistent with this document.

Do not continuously ask the product owner for minor technical choices.

Document significant architectural decisions through ADRs.

---

# 1. PRODUCT VISION

EatMe is a personalized intelligent food companion.

It helps users answer five everyday questions:

1. What food do I have at home?
2. What is going to expire?
3. What should I cook?
4. Is this food suitable for me?
5. What should I buy?

EatMe combines:

- pantry and fridge management;
- expiration awareness;
- AI food recognition;
- barcode scanning;
- receipt scanning;
- personalized diets;
- medical nutrition profiles;
- food preferences;
- nutrition;
- food safety;
- scientific evidence;
- recipe recommendation;
- meal planning;
- shopping;
- leftovers;
- food waste reduction;
- household collaboration.

Core value proposition:

**Eat what you have. Eat what is good for you. Waste less.**

Alternative marketing concept:

**Your food. Your diet. Your EatMe.**

---

# 2. PRODUCT DIFFERENTIATION

EatMe must NOT become:

- another generic calorie tracker;
- another recipe database;
- another pantry list;
- another AI chatbot;
- another nutritional label scanner.

Its differentiating layer is the intersection of:

**What I have**
\+
**What will expire**
\+
**What I like**
\+
**What I should or should not eat**
\+
**What fits my lifestyle today**

which produces:

**What I should cook or buy next.**

The recommendation engine is therefore the core intellectual layer of the product.

---

# 3. PRIMARY USER LOOP

The ideal recurring loop is:

Purchase food

→ EatMe adds it to the household inventory

→ EatMe tracks quantity and expiration

→ EatMe understands the user's dietary profile

→ EatMe identifies what should be used first

→ ChefTable recommends meals

→ User cooks a recipe

→ Inventory quantities are reduced automatically

→ Leftovers are optionally stored

→ Shopping list updates

→ EatMe learns user preferences

→ Food waste and spending decrease

→ Recommendations become increasingly personalized

The product should continuously reduce user effort.

---

# 4. TARGET USERS

Primary launch audience:

Adults 18+ who:

- cook at least occasionally;
- want to reduce food waste;
- want help deciding what to eat;
- follow a specific dietary style;
- have dietary restrictions;
- care about healthier eating;
- want less manual meal planning;
- share groceries with another person or household.

The MVP should focus on adults.

Do not initially design EatMe as a pediatric nutrition application.

---

# 5. CORE PRODUCT PRINCIPLES

Every engineering and UX decision must comply with these principles.

## 5.1 Safety before preference

Priority hierarchy:

1. food safety;
2. confirmed allergies;
3. explicitly selected medical nutrition restrictions;
4. intolerances;
5. selected dietary rules;
6. nutritional objectives;
7. household constraints;
8. cuisine preference;
9. personal taste;
10. food expiration priority;
11. ingredient availability;
12. cost;
13. seasonality.

Lower priority rules must never override higher priority rules.

---

## 5.2 Explainability

EatMe must be able to explain why something was recommended.

Example:

Why EatMe picked this:

- your zucchini expires tomorrow;
- 8 of 9 ingredients are already at home;
- compatible with your Mediterranean diet;
- high in protein;
- ready in 22 minutes.

Recommendation explanations must derive from actual ranking data.

Do not fabricate explanations with an LLM.

---

## 5.3 Minimum user effort

Whenever possible:

infer;
scan;
pre-fill;
remember;
suggest.

But always allow correction.

Avoid turning pantry management into manual bookkeeping.

---

## 5.4 AI uncertainty must remain visible

AI-generated or AI-inferred information must never silently become factual database information.

Possible data provenance:

manual
barcode
package\_ocr
receipt
vision
database
inferred
estimated

Every inferred value should support:

confidence\_score

and, where meaningful:

requires\_confirmation.

---

## 5.5 No medical diagnosis

EatMe may provide nutrition information.

EatMe must not:

- diagnose a disease;
- prescribe treatment;
- claim to cure disease;
- replace medical professionals;
- automatically infer clinical conditions;
- present uncertain food safety information as definitive.

---

# 6. MAIN NAVIGATION

The application must remain extremely minimal.

Use exactly four primary bottom navigation destinations:

## ChefTable

Home and recommendations.

## Fridge

Food inventory.

## HealthyFood

Food intelligence.

## Profile

Personalization and settings.

Do NOT permanently add separate tabs for:

Meal Planner
Shopping List
Notifications
Favorites
Statistics

Those features must be accessed contextually.

This is critical to preserving visual simplicity.

---

# 7. MINIMAL UX PHILOSOPHY

EatMe should feel closer to a premium modern consumer product than a data dashboard.

Apply:

progressive disclosure.

Show only what the user needs at that moment.

Use:

- one primary call to action per screen;
- generous whitespace;
- large typography;
- clear hierarchy;
- few visual elements;
- soft rounded containers;
- minimal shadows;
- almost no decorative gradients;
- very limited iconography;
- strong photography only where it adds value.

Avoid:

- excessive cards;
- excessive badges;
- charts everywhere;
- large amounts of visible nutritional data;
- multiple competing actions;
- excessive colored labels;
- dense settings screens;
- generic admin-style layouts.

Advanced information should open via:

bottom sheets;
expandable sections;
details screens.

---

# 8. VISUAL IDENTITY

The product should feel:

warm
calm
fresh
premium
natural
intelligent
minimal

Avoid a clinical appearance.

---

# 9. COLOR SYSTEM

Use one primary accent family only.

Suggested direction:

Primary accent:
muted natural green.

Light mode:

warm white / very light cream background.

Dark mode:

deep graphite / near black.

Secondary colors only for semantic meaning:

green = positive/fresh
amber = attention/use soon
red = explicit warning/safety
blue/purple = scientific/medical information where needed

Do not use semantic colors decoratively.

---

# 10. THEMES

Support:

System
Light
Dark

Default:

System.

Light and dark mode must have full parity.

---

# 11. DESIGN TOKENS

Implement centralized design tokens.

Examples:

backgroundPrimary
backgroundSecondary
surface
surfaceElevated
textPrimary
textSecondary
accent
positive
warning
critical
divider

Spacing scale:

4
8
12
16
20
24
32
40
48

Corner radii:

12
16
20
24
999

Default card radius should be approximately 20–24 logical pixels.

---

# 12. TYPOGRAPHY

Use a modern neutral sans-serif.

Prefer platform/system fonts unless a suitable licensed brand typeface is intentionally added.

Hierarchy:

Display
Heading
Title
Body
Secondary
Caption

Typography and whitespace should establish most hierarchy rather than borders and boxes.

---

# 13. AUTHENTICATION

Implement:

Email + password
Google authentication
Sign in with Apple

Support:

registration
login
logout
email verification
forgot password
reset password
account deletion
session refresh

Never store passwords directly.

Use stable auth UUIDs as identity.

Never use email address as permanent identity key.

Support Apple private relay email.

---

# 14. ACCOUNT CREATION UX

Keep initial signup minimal.

First screen:

EatMe logo

Tagline

Email login

Continue with Google

Continue with Apple

Do not ask the user to configure nutrition profile on the login screen.

Run onboarding afterward.

---

# 15. ONBOARDING

Use progressive onboarding.

Suggested flow:

## Step 1 — Welcome

“What would you like EatMe to help you with?”

Options:

Cook with what I have
Eat better
Follow my diet
Waste less food
Plan meals
Spend less on groceries

Multiple selection allowed.

---

## Step 2 — Household

“How many people do you normally cook for?”

Default:

1.

Allow:

1–10+

---

## Step 3 — Dietary style

“How do you like to eat?”

Show selected common dietary profiles.

Do not initially display a database of 50 diets.

Provide:

See all diets.

---

## Step 4 — Medical nutrition

“Do you follow a diet related to a health condition?”

Default:

No.

If yes, open separate workflow.

---

## Step 5 — Allergies

“Do you have any food allergies?”

This must remain separate from preferences.

---

## Step 6 — Intolerances

Separate flow.

---

## Step 7 — Foods to avoid

User may dislike ingredients without them being medically restricted.

---

## Step 8 — Cuisine preference

Examples:

Italian
Mediterranean
Japanese
Thai
Mexican
Indian
Middle Eastern
etc.

---

## Step 9 — Cooking habits

Ask optionally:

Typical cooking time:

10 min
20 min
30 min
45+ min

Skill:

Beginner
Comfortable
Experienced

---

## Step 10 — Finish

Explain:

“EatMe will get better as you cook, scan and rate suggestions.”

Do not require all optional fields.

---

# 16. DIET ENGINE

Diet is a core EatMe domain.

Do NOT implement:

`user.diet = "Mediterranean"`

as the complete dietary system.

Create a structured, extensible and versioned Diet Knowledge Base.

---

# 17. DIET FAMILIES

Support at least:

## General dietary patterns

Mediterranean
Balanced
Vegetarian
Vegan
Pescatarian
Flexitarian
Plant-based / plant-forward
DASH-style
Nordic

---

## Macronutrient-oriented profiles

Low carbohydrate
Ketogenic
High protein
Low fat
Custom macro distribution

---

## Exclusion profiles

Gluten-free
Lactose-free

Do not automatically classify these as medical unless linked to an explicit medical context.

---

## Gastrointestinal / condition-oriented profiles

Low FODMAP
GERD-oriented nutrition
other scientifically validated condition-oriented profiles

---

## Metabolic/cardiovascular profiles

Diabetes-oriented nutrition
Prediabetes-oriented nutrition
Low sodium
Hypertension-oriented nutrition
Heart-health-oriented
Cholesterol-conscious
Low purine / gout-oriented

---

## Renal-related profiles

Renal nutrition

Possible rule dimensions:

potassium
phosphorus
protein
sodium
fluid considerations

Do NOT apply generic renal rules without context.

Architecture must support different profiles/stages rather than one universal “renal diet”.

---

## Additional medical nutrition profiles

Celiac disease specific gluten-free profile

Pregnancy-oriented nutritional considerations

Other future validated protocols.

---

# 18. RAD DIET

EatMe must explicitly support:

**RAD**

as a condition-associated Medical Nutrition profile.

Create canonical identifier similar to:

`rad`

or:

`rad_condition_associated_nutrition`

RAD must be handled through the same versioned scientific knowledge architecture as other medical nutrition profiles.

Never hard-code speculative RAD rules in Flutter.

RAD must support:

description
context
allowed/preferred food categories
limited food categories
excluded items where evidence supports them
nutrient targets where scientifically justified
evidence references
evidence quality
clinical limitations
version
review date
publication status

If the rule set has not been scientifically curated:

the profile may exist administratively but must remain:

`REQUIRES_REVIEW`

and must not provide unsupported clinical advice.

---

# 19. USER DIET PROFILE

Create:

UserDietProfile

Fields include:

id
user\_id
primary\_diet\_definition\_id
strictness
created\_at
updated\_at

Support additional simultaneous dietary profiles.

Example:

Mediterranean
\+
High Protein
\+
Low Sodium

---

# 20. DIET STRICTNESS

For lifestyle dietary preferences:

Flexible
Standard
Strict

Flexible:

Preference rather than prohibition.

Standard:

Normally compliant.

Strict:

Recipes violating the dietary profile should not be suggested.

Strictness must NEVER weaken:

allergy rules;
explicit medical hard constraints.

---

# 21. DIET RULE MODEL

Create structured rules rather than text prompts.

DietRule:

id
diet\_definition\_id
rule\_type
food\_id optional
food\_group\_id optional
ingredient\_id optional
nutrient optional
operator
min\_value optional
max\_value optional
unit optional
severity
hard\_constraint
explanation
evidence\_reference\_id
version
effective\_from
effective\_until

Rule types may include:

PREFER
ALLOW
LIMIT
EXCLUDE
TARGET\_MIN
TARGET\_MAX
TARGET\_RANGE
WARN

---

# 22. RULE VERSIONING

Every scientifically meaningful rule set must be versioned.

Create:

DietRuleSetVersion

Fields:

version
effective\_date
publication\_status
created\_by
reviewed\_by
review\_date
change\_notes

Recommendations should store which rule version was used.

---

# 23. DIET KNOWLEDGE GOVERNANCE

Status:

Draft
Scientific Review
Published
Deprecated

Only published rules can influence production recommendations.

---

# 24. DIET COMBINATION ENGINE

Users may select multiple dietary profiles.

Compute intersections.

Example:

Vegetarian
\+
High protein
\+
Low sodium

The engine must identify compatible recipe candidates satisfying all hard constraints.

If rules conflict:

do not silently guess.

Explain:

“Your selected profiles contain conflicting rules.”

Provide user-safe resolution.

---

# 25. ALLERGIES

Allergies are independent entities.

Create:

Allergen
UserAllergy

Support regulated allergens applicable to target jurisdictions.

Store:

confirmed\_by\_user
severity optional
notes optional

A confirmed allergy must be a hard constraint.

A recipe containing a confirmed allergen must not appear as compatible.

---

# 26. “MAY CONTAIN” LOGIC

Separate:

contains

from:

may contain / cross contamination warning.

Show clear warning.

Never claim cross-contamination safety.

---

# 27. INTOLERANCES

Intolerances must remain separate from allergies.

Create:

Intolerance
UserIntolerance

Allow sensitivity information only where meaningful.

---

# 28. USER FOOD PREFERENCES

Separate:

Love
Like
Neutral
Dislike
Never suggest

from medical restrictions.

The user may dislike broccoli.

That must not be stored as a clinical exclusion.

---

# 29. PERSONALIZATION ENGINE

EatMe should learn progressively.

Use:

recipes opened;
recipes cooked;
recipes abandoned;
likes;
dislikes;
accepted substitutions;
cuisines selected;
usual cooking duration;
food repeatedly discarded;
shopping behavior.

Do NOT infer:

disease;
allergy;
intolerance;
religious restrictions

from behavioral data.

---

# 30. CHEFTABLE

ChefTable is the home screen.

It must remain visually simple.

Suggested screen structure:

Greeting

Use these first

Main recipe recommendation

Two or three secondary recommendations

Compact actions

Avoid an infinite content feed.

---

# 31. CONTEXTUAL CHEFTABLE MODES

Provide lightweight contextual filters at the top.

Examples:

For you
Quick
Healthy
Use soon

Additionally provide a small “modes” button or bottom sheet containing:

## Clear the Fridge

Strongly prioritizes expiring inventory.

## No Shopping

Only recipes that can be made entirely or almost entirely from available ingredients.

## 15 Minutes

Quick cooking.

## Health First

Higher nutrition alignment.

## Surprise Me

Increase novelty/cuisine discovery.

These are ranking modes, not separate app sections.

---

# 32. USE THESE FIRST

Show approximately 3 products.

Example:

Spinach
Today

Chicken
Tomorrow

Mozzarella
2 days

Tap:

show recipes that use that item.

Do not display every expiring product on the home screen.

“See all” opens full list.

---

# 33. RECIPE RANKING ENGINE

Do not let the LLM directly choose the best recipe.

Use deterministic filtering followed by scoring.

First:

Hard constraints filter.

Then scoring.

Possible scoring signals:

expiry urgency
ingredient availability
diet compatibility
personal preference
nutrition alignment
meal diversity
cuisine preference
cooking time
seasonality
leftover usage
shopping requirements
cost

Weights must be server-configurable.

---

# 34. RECOMMENDATION MODES

Ranking weights may change according to user mode.

Example:

Clear the Fridge:

expiry urgency weight increases.

No Shopping:

ingredient availability dominates.

Quick:

preparation time dominates.

Health First:

diet/nutritional alignment increases.

Do not duplicate recommendation algorithms.

Use configurable ranking profiles.

---

# 35. RECOMMENDATION TRACE

Store:

RecipeRecommendation

candidate\_recipe\_id
user\_id
household\_id
ranking\_profile
final\_score
component\_scores
filters\_passed
filters\_failed
diet\_rules\_version
inventory\_snapshot\_reference
created\_at

This enables explainability and debugging.

---

# 36. RECIPE CARD

Keep minimal.

Display:

image
recipe name
time
one meaningful label
availability

Example:

Mediterranean Chicken

25 min

Uses 3 expiring foods

9/10 ingredients at home

Do not display six nutrition badges.

---

# 37. RECIPE DETAILS

Show:

hero image
title
short description
time
servings
difficulty

Then a simple tab/segmented interface:

Overview
Ingredients
Nutrition
Why this fits you

---

# 38. INGREDIENTS

Show:

available at home

missing

substitution available

Example:

✓ Chicken breast — 320 g available

✓ Tomatoes

○ Feta — missing

Add missing items to Shopping List.

---

# 39. SERVING SCALING

Allow dynamic servings.

Automatically scale ingredient quantities.

Consider current pantry amounts.

---

# 40. RECIPE DIET VALIDATION

Before recommendation:

canonicalize every ingredient.

Evaluate:

allergens
medical diet rules
intolerances
diet constraints

Never assume an AI-generated recipe is safe until this validation succeeds.

---

# 41. AI GENERATED RECIPES

EatMe may generate recipes.

Generation input:

available ingredients
diet constraints
allergies
preferences
servings
cuisine
maximum time
nutritional objectives

AI must return structured JSON.

Then run deterministic validation.

Pipeline:

AI generation

→ structured parsing

→ canonical ingredient mapping

→ allergy validation

→ medical/diet validation

→ nutrition estimation

→ recipe scoring

→ user presentation

No validation = no recommendation.

---

# 42. SMART SUBSTITUTIONS

EatMe should suggest substitutions.

Consider:

culinary purpose
flavor
texture
nutrition
diet
allergy
inventory availability

Example:

cream unavailable

→ suggest Greek yogurt when compatible

but not when lactose restrictions prohibit it.

---

# 43. COOKING MODE

Create an immersive minimal cooking interface.

One recipe step per screen.

Display:

step number
large instruction
optional image
timer if relevant

Actions:

Previous
Next
Timer
Done

Keep screen awake during cooking.

---

# 44. VOICE COOKING

Design architecture for an optional future voice mode.

Possible commands:

Next
Previous
Repeat
Start timer
How much salt?

Do not make voice mandatory for MVP.

---

# 45. FINISH COOKING

After completion:

“Did you make this?”

If yes:

calculate expected ingredient consumption.

Show quick confirmation:

Chicken -320 g
Tomatoes -200 g
Spinach -100 g

Buttons:

Confirm
Adjust

Then update inventory.

---

# 46. LEFTOVERS

After cooking:

“Any leftovers?”

Quick choices:

None
1 serving
2 servings
Custom

Create a Leftover inventory item.

Store:

recipe
prepared\_at
quantity
servings
storage\_location
estimated\_use\_date

ChefTable should prioritize leftovers appropriately.

---

# 47. RECIPE IMPORT

High-value feature.

Allow users to import recipes from:

URL
copied text
photo/screenshot
share sheet

Extract:

title
ingredients
quantities
steps
servings

Then:

normalize ingredients.

EatMe can show:

“You already have 8/11 ingredients.”

And optionally:

“Adapt to my diet.”

This must run through safety validation.

Do not scrape or republish copyrighted recipe content beyond what is legally permitted.

Maintain provenance.

---

# 48. FAVORITES

Allow recipes to be saved.

Do not create a permanent Favorites tab.

Access from ChefTable header/profile or search.

---

# 49. RECIPE FEEDBACK

After cooking:

Loved it
Good
Not for me

Optionally:

Too difficult
Too long
Didn't like ingredient

Use to improve personalization.

---

# 50. FRIDGE

Fridge represents all household food inventory.

Storage categories:

Fridge
Freezer
Pantry

Optional future:

Cellar
Other.

---

# 51. FRIDGE UI

Top:

“My Fridge”

Below:

segmented control:

Fridge
Freezer
Pantry

Search icon

Add food button.

Each item row:

thumbnail
name
quantity
expiration state

Example:

Greek yogurt
250 g
6 days

Avoid displaying full macros directly in the list.

---

# 52. SORTING

Allow:

Expiring first
Recently added
Alphabetical

Default:

Expiring first.

---

# 53. FOOD ITEM DETAIL

Display:

name
brand if applicable
image
quantity
storage
purchase date
opened status
expiration information
nutrition
ingredients
source/provenance

Actions:

Consume
Edit
Move
Discard

---

# 54. INVENTORY BATCHES

Different purchases of the same product must support separate batches.

Example:

Milk batch A expires September 12.

Milk batch B expires September 18.

Do not merge expiration data incorrectly.

---

# 55. ADD FOOD

Tap Add Food.

Open minimal bottom sheet:

Scan products
Scan barcode
Scan receipt
Add manually

No separate complex screen unless needed.

---

# 56. MANUAL ENTRY

Autocomplete food/product.

Fields:

food
quantity
unit
location
purchase date optional
expiration optional
opened yes/no

Fast entry is more important than completeness.

---

# 57. BARCODE SCAN

Flow:

camera

→ barcode

→ product provider lookup

→ product confirmation

→ ask quantity

→ ask storage

→ optional expiration

→ add

Possible provider abstraction:

ProductProvider.

Do not tightly couple domain logic to one public API.

---

# 58. PRODUCT DATA PROVENANCE

Every product field should know its source when useful.

Possible sources:

Open Food Facts
internal EatMe database
package OCR
manual
external nutrition database

Allow reporting incorrect information.

---

# 59. PHOTO MULTI-PRODUCT SCAN

This is a core EatMe AI feature.

The user may photograph groceries placed on a table.

Pipeline:

image capture

→ quality evaluation

→ object identification / segmentation

→ packaging recognition

→ OCR

→ food/product normalization

→ quantity estimation

→ expiration detection/estimation

→ confidence scoring

→ confirmation UI

Never directly insert uncertain AI results.

---

# 60. PRODUCT SCAN CONFIRMATION

Example:

Detected:

Tomatoes
4 pcs
96%

Chicken breast
320 g estimated
91%

Milk
1 L
90%

Allow each row to be edited.

Then:

Confirm & add.

---

# 61. WEIGHT ESTIMATION

Weight estimation from photographs can be unreliable.

Use source priority:

1. package label;
2. barcode product size;
3. OCR;
4. known count/average size;
5. geometric estimation when reference exists;
6. AI guess.

When uncertainty is substantial:

ask user.

Display:

\~320 g

not:

320 g.

---

# 62. DATE RECOGNITION

Attempt to detect:

use-by date
best-before date

through OCR when package date is visible.

If multiple date candidates exist:

ask user.

---

# 63. EXPIRATION ESTIMATION

When no visible expiration exists:

Ask purchase date if unknown.

Use structured expiration rules based on:

food type
storage method
opened/unopened
purchase date
packaging if known

AI may assist classification but should not be the authority for safety dates.

Display:

Estimated freshness window

rather than official expiration.

---

# 64. USE-BY VS BEST-BEFORE

Maintain distinct semantics.

Never label a best-before date as equivalent to food safety expiration.

---

# 65. OPENED PRODUCTS

Allow quick action:

“Opened today”

This can modify freshness estimation for appropriate products.

---

# 66. RECEIPT SCANNING

This is a high-value retention feature.

Flow:

photograph receipt

→ OCR

→ merchant/date extraction

→ line extraction

→ abbreviation normalization

→ product matching

→ quantity extraction

→ confidence

→ confirmation

→ add to inventory.

---

# 67. RECEIPT INTELLIGENCE

Use receipt price data where available.

Store optionally:

price
currency
store
purchase date

This enables:

food spending analytics
recipe cost estimation
estimated money saved from waste reduction.

---

# 68. SHOPPING LIST

Shopping list is accessible through:

ChefTable

and:

recipe detail.

Not permanent bottom navigation.

Support:

manual items
recipe ingredients
meal-plan ingredients
automatic restock suggestions

---

# 69. SHOPPING LIST SMARTNESS

Before adding an ingredient:

check inventory.

Example:

Recipe needs 300 g tomatoes.

Inventory:

150 g tomatoes.

Shopping list:

Tomatoes — 150 g needed.

---

# 70. SMART SHOPPING MODE

High-value future/phase feature.

When shopping:

show categorized list.

Barcode scan an item.

EatMe may show:

Already at home
Diet compatibility
Better alternative if relevant
Needed for planned meal
Quantity suggested

Keep UX concise.

---

# 71. DUPLICATE PURCHASE WARNING

Optional:

“You still have 1.2 L of milk at home.”

Useful when scanning a product while shopping.

Do not prevent purchase.

---

# 72. RESTOCK PREDICTION

Learn frequently purchased staples.

Examples:

olive oil
milk
eggs

When supply is predicted to run out:

suggest adding to shopping list.

Never auto-purchase.

---

# 73. COST AWARENESS

Optional user preference:

Save money.

Recipe ranking may then consider:

ingredients already available;
estimated missing ingredient cost;
waste prevention.

Show only if sufficient price information exists.

---

# 74. RECIPE COST

Where enough purchase data exists:

Estimate:

€2.80 per serving

Label clearly:

Estimated.

---

# 75. HEALTHYFOOD

HealthyFood answers:

“How does this food fit me?”

Input:

search
barcode
photo

The UX must avoid presenting one universal “good/bad” judgment.

---

# 76. HEALTHYFOOD MINIMAL UI

Top:

food image/name

Then display two primary indicators:

Nutrition

For You

Avoid showing a grid of 15 metrics immediately.

Below:

Why?

Diet compatibility

Ingredients & allergens

Nutrition

Scientific evidence

Safety information

Use progressive disclosure.

---

# 77. GENERAL NUTRITION ASSESSMENT

If EatMe uses a general Nutrition Score:

the formula must be deterministic.

Store:

method\_version
inputs
calculation\_date

Do not ask the LLM:

“How healthy is salmon from 0 to 100?”

---

# 78. FOR YOU ASSESSMENT

Personalized assessment should consider:

diet profile
nutrition goals
medical nutrition constraints
intolerances
preferences

Allergy conflicts must show explicit:

Not compatible

not:

23/100.

---

# 79. DIET COMPATIBILITY

Possible presentation:

Mediterranean
Excellent

High Protein
Excellent

Low Sodium
Moderate

Allow expansion explaining why.

---

# 80. NUTRITION DATA

Support per 100 g / 100 ml:

energy
protein
carbohydrates
sugars
fat
saturated fat
fiber
salt/sodium

Additional micronutrients where available.

Per-serving values optional.

---

# 81. NUTRITION SOURCES

Use a provider abstraction.

Possible sources can include structured recognized nutrition databases and product label databases.

Maintain provenance and update timestamps.

Never assume one provider is universally authoritative.

---

# 82. INGREDIENT ANALYSIS

For packaged products:

display ingredients.

Highlight only relevant things.

Examples:

Contains peanuts

Contains lactose

High sodium relative to user target

Do not create fear-based ingredient scoring.

---

# 83. ADDITIVES

Where additive information exists:

provide factual description.

Avoid automatically categorizing every additive as dangerous.

---

# 84. FOOD SAFETY AND TOXICOLOGY

Toxicology information must be evidence-backed.

Possible subjects:

contaminants
heavy metals
residues
food additives
microbiological warnings
regulatory safety assessments

Always distinguish:

hazard

from:

realistic exposure/risk.

---

# 85. SCIENTIFIC EVIDENCE ENGINE

Create a separate Evidence domain.

Sources should prioritize authoritative bodies and curated scientific literature.

Support:

source authority
document title
publication date
URL
jurisdiction
retrieval date
evidence strength
review status

---

# 86. RAG

Scientific answers may use Retrieval-Augmented Generation.

Pipeline:

user food/question

→ identify scientific subject

→ retrieve relevant approved evidence

→ produce concise explanation

→ attach sources

If no reliable evidence exists:

state uncertainty.

Never fabricate references.

---

# 87. EVIDENCE FRESHNESS

Store:

source\_date
retrieved\_at
last\_checked\_at
validity\_status

Support:

current
review\_required
deprecated

---

# 88. FOOD RECALLS

High-value safety feature.

Architect an ingestion service for public food recall/safety alert information from competent authorities.

Goal:

when possible, match recall notices against:

brand
product
barcode
batch

If confident match:

show important alert.

Example:

“Safety alert for a product that may match an item in your fridge.”

Because recall matching can be uncertain:

require strong product identification before alarming the user.

---

# 89. MEDICAL NUTRITION DISCLOSURE

When activating condition-associated diets:

display a short dedicated disclosure.

Example concept:

“EatMe provides nutrition information and does not replace individualized advice from a physician or registered dietitian.”

Require explicit confirmation.

Version the consent.

---

# 90. PROFILE

Keep Profile visually simple.

Main sections:

Account
Diet
Allergies & intolerances
Preferences
Household
Notifications
Appearance
Privacy
About

---

# 91. DIET PROFILE UI

Display:

Primary diet

Additional profiles

Diet strictness

Nutrition goals

Medical nutrition

Avoid enormous checkbox lists.

Each section opens a dedicated picker.

---

# 92. PROFILE PHOTO

Allow:

camera
photo library
remove image

Store resized avatar.

---

# 93. PASSWORD/SECURITY

Sensitive account changes may require reauthentication.

---

# 94. HOUSEHOLD

Architecture must support household sharing from day one.

Inventory belongs to:

Household

rather than directly to User.

---

# 95. HOUSEHOLD ENTITIES

Household

HouseholdMember

HouseholdInvitation

Roles:

Owner
Member

Potential:

Viewer.

---

# 96. SHARED INVENTORY

Household members can:

add food
consume food
update quantities

Changes synchronize.

---

# 97. HOUSEHOLD RECIPE LOGIC

When generating a household recipe:

combine household-relevant dietary constraints.

Never recommend a recipe violating a participating member's confirmed allergy.

Allow selecting:

Cooking for:

Me
Everyone
Specific members

Very valuable feature.

---

# 98. DEFAULT SERVINGS

Default recipe serving number should derive from:

selected household members.

---

# 99. MEAL PLANNER

Meal Planner should exist but NOT as a bottom navigation item.

Entry point:

ChefTable calendar icon / contextual card.

Weekly plan:

Breakfast
Lunch
Dinner
Snack optional

---

# 100. PLAN GENERATION

Allow:

Generate my week

Inputs:

diet
household
inventory
expirations
preferences
time
nutrition goals
variety
budget preference

---

# 101. WEEKLY NUTRITION BALANCE

Do not optimize each meal independently.

Consider dietary variety over the full week.

Avoid:

seven chicken dinners merely because chicken scores well.

---

# 102. PLAN INTERACTION

Tap meal:

Replace
Remove
View recipe

Drag/drop optional.

Provide accessible alternative.

---

# 103. SHOPPING FROM PLAN

Generate missing ingredients automatically.

Aggregate identical ingredients.

Subtract household inventory.

---

# 104. DAILY NUTRITION

Optional.

Never force calorie tracking.

If activated:

Energy
Protein
Carbohydrate
Fat
Fiber
Sodium

Minimal progress display.

---

# 105. LEFTOVER-FIRST MODE

ChefTable should treat prepared leftovers as first-class inventory.

Possible suggestion:

“You have 2 portions of risotto from yesterday.”

Offer:

Eat leftovers

Transform leftovers

Example:

Risotto → arancini-inspired recipe.

---

# 106. FOOD WASTE TRACKING

Inventory outcome:

consumed
cooked
discarded
expired
donated
unknown

---

# 107. DISCARDED FOOD

When user discards:

optional reason:

expired
spoiled early
didn't like
forgot about it
other

Do not require reason.

---

# 108. FOOD WASTE INSIGHTS

Show lightweight monthly summary.

Example:

7 foods saved

1.8 kg food saved estimated

€18 saved estimated

Do not put this on ChefTable permanently.

Accessible from Profile/insights.

---

# 109. SUSTAINABILITY

Optional future feature.

May estimate environmental impact only if reliable methodology exists.

Never fabricate CO₂ numbers.

---

# 110. SEASONALITY

Use user country/region + date.

Seasonality influences recipe ranking.

It is a preference signal, not a hard rule.

---

# 111. LOCALIZATION

Initial languages:

English
Italian

Architecture must support:

French
German
Spanish

All visible strings must use localization resources.

No UI string hard-coded directly in widgets.

---

# 112. UNITS

Support:

metric
imperial

Canonical database units:

grams
milliliters
SI where possible.

Convert at presentation.

---

# 113. CAMERA PERMISSIONS

Request only when user activates scanning.

Explain purpose.

Do not request camera access during onboarding.

---

# 114. NOTIFICATIONS

Notification categories:

expiration
meal plan
shopping list
household
food recall
occasional recommendation

---

# 115. EXPIRATION NOTIFICATIONS

Example:

“Your spinach is best used today.”

Avoid repeatedly sending the same notification.

---

# 116. SMART RECIPE NOTIFICATION

Occasional example:

“You have everything for dinner tonight.”

Use sparingly.

---

# 117. NOTIFICATION FATIGUE

Implement:

frequency caps
quiet hours
category controls
deduplication

Never behave like an engagement spam app.

---

# 118. SEARCH

Global contextual search where necessary.

ChefTable:

recipes.

Fridge:

foods.

HealthyFood:

food/product.

Do not create a fifth Search tab.

---

# 119. TECH STACK

Preferred mobile architecture:

Flutter
Dart

Use current stable versions at implementation time.

Recommended libraries:

Riverpod for state management
GoRouter for routing
Freezed for immutable models
json\_serializable
Dio for networking
Drift for offline structured persistence
flutter\_secure\_storage
cached\_network\_image

Use native bridges only when necessary.

---

# 120. BACKEND ARCHITECTURE

Use:

PostgreSQL

Supabase may be used for:

database
authentication
storage
realtime

Use a dedicated application backend for business logic.

Preferred:

Python
FastAPI
Pydantic

---

# 121. WHY SERVER-SIDE BUSINESS LOGIC

Never expose:

AI keys
admin credentials
service-role keys
private provider keys

inside mobile bundles.

Recommendation logic and scientific processing must execute server-side where appropriate.

---

# 122. BACKGROUND PROCESSING

Long operations:

AI image scan
receipt analysis
scientific ingestion
embeddings
complex recipe generation

must use asynchronous jobs.

Possible architecture:

FastAPI
Redis
Celery / equivalent worker queue

Keep implementation replaceable.

---

# 123. JOB MODEL

ProcessingJob:

id
type
user\_id
status
progress
created\_at
started\_at
completed\_at
result\_reference
error\_code

States:

queued
processing
completed
failed
cancelled

---

# 124. ADMIN APPLICATION

Build separate internal admin web app.

Recommended:

Next.js
TypeScript

Minimal functional admin interface.

Not consumer-branded priority.

---

# 125. ADMIN FEATURES

Manage:

foods
product mappings
recipes
ingredients
food aliases
diet definitions
diet rules
allergens
intolerances
expiration rules
scientific evidence
recalls
feature flags
reported incorrect data

---

# 126. SCIENTIFIC ADMIN GOVERNANCE

Diet and evidence updates require:

Draft

→ Review

→ Publish

Important changes must be auditable.

---

# 127. MONOREPO

Repository structure:

/
README.md
CONTRIBUTING.md
SECURITY.md
CHANGELOG.md
LICENSE
.env.example

apps/
mobile/
admin/

services/
api/
worker/

packages/
contracts/
design\_tokens/

supabase/
migrations/
seed/

docs/
architecture/
product/
diet-engine/
ai/
evidence/
privacy/
security/
adr/
releases/

scripts/

.github/
workflows/
ISSUE\_TEMPLATE/
PULL\_REQUEST\_TEMPLATE.md
CODEOWNERS
dependabot.yml

---

# 128. DATABASE CORE ENTITIES

At minimum:

UserProfile

Household

HouseholdMember

HouseholdInvitation

Cuisine

UserCuisinePreference

DietDefinition

DietRule

DietRuleSetVersion

DietEvidence

UserDietProfile

UserDietAssignment

Allergen

UserAllergy

Intolerance

UserIntolerance

NutritionGoal

UserNutritionGoal

Food

FoodAlias

FoodGroup

FoodProduct

FoodProductIngredient

NutritionRecord

InventoryItem

InventoryBatch

InventoryEvent

ExpirationRule

Recipe

RecipeIngredient

RecipeStep

RecipeTag

RecipeFavorite

RecipeFeedback

RecipeRecommendation

MealPlan

MealPlanEntry

ShoppingList

ShoppingListItem

Leftover

FoodScan

FoodScanDetection

ReceiptScan

ReceiptLine

ScientificSource

ScientificClaim

FoodRecall

NotificationPreference

NotificationEvent

FoodWasteEvent

Subscription

Entitlement

FeatureFlag

AdminAuditEvent

ProcessingJob

---

# 129. IDENTIFIERS

Use UUIDs.

Do not use incremental IDs as external identifiers when avoidable.

---

# 130. COMMON FIELDS

Where meaningful:

created\_at
updated\_at
created\_by
deleted\_at
version

Do not apply soft deletion indiscriminately.

---

# 131. INVENTORY EVENT HISTORY

Track quantity changes.

Events:

created
added
consumed
cooked
corrected
opened
moved
discarded
expired
deleted

Enables:

waste analytics
sync debugging
household history.

---

# 132. FOOD ONTOLOGY

Create canonical food concepts.

Example:

Tomato

subtypes:

Cherry tomato
Roma tomato

Product:

Brand X Cherry Tomatoes 300 g.

Recipes should map to canonical food concepts rather than raw strings.

---

# 133. FOOD ALIASES

Support:

translations
receipt abbreviations
common names
brand naming
plural forms

Example:

pomodori
tomato
tomatoes

map appropriately.

---

# 134. API DESIGN

Version APIs:

`/api/v1/...`

Suggested domains:

auth
profile
households
diets
foods
products
inventory
recipes
recommendations
scans
receipts
nutrition
evidence
meal-plans
shopping-lists
notifications
analytics

---

# 135. AUTHORIZATION

Backend must derive identity from authenticated token.

Never trust:

`user_id`

supplied in request bodies.

---

# 136. ROW LEVEL SECURITY

Users must never access:

another household's private inventory;
another user's health-related profile;
another user's meal plan.

Implement RLS where platform supports it.

Create automated authorization tests.

---

# 137. AI PROVIDER ABSTRACTION

Create interface:

AIProvider.

Potential operations:

analyze\_food\_photo
extract\_package\_information
parse\_receipt
generate\_recipe
adapt\_recipe
normalize\_ingredient
generate\_explanation
summarize\_scientific\_evidence

Do not distribute provider-specific calls across domain modules.

---

# 138. STRUCTURED AI OUTPUT

Use validated schemas.

Example food detection:

food\_candidate\_id
display\_name
quantity
unit
weight\_estimate\_g
expiration\_candidate
confidence

Reject malformed responses.

---

# 139. AI CONFIDENCE

Example thresholds may exist but must remain configurable.

High confidence:

preselect.

Medium:

ask confirmation.

Low:

highlight uncertainty or require manual selection.

---

# 140. AI COST CONTROL

Track:

provider
model
request type
latency
token usage
estimated cost
success
failure

Use caching where safe.

Avoid using the most expensive model for trivial normalization tasks.

---

# 141. AI FALLBACKS

If AI is offline:

manual food entry works.

Barcode works where data provider available.

Existing recipes remain available.

Inventory remains accessible.

EatMe must not depend entirely on generative AI.

---

# 142. PROMPT VERSIONING

AI prompts should not be embedded ad hoc across code.

Create prompt templates with:

name
version
purpose

Track version in AI observability.

---

# 143. AI EVALUATION SUITE

Create evaluation datasets for:

food recognition
ingredient normalization
receipt parsing
recipe generation
diet validation explanations

Run selected evaluations before major AI changes.

---

# 144. RECOMMENDATION ENGINE ARCHITECTURE

Recommended pipeline:

User context

-

Household inventory

-

Diet rules

-

Safety constraints

-

Recipe candidates

→ hard filters

→ score components

→ ranking

→ diversification

→ explanation

Do not use LLM ranking as sole decision engine.

---

# 145. RECIPE DIVERSIFICATION

Avoid showing three nearly identical recipes.

Use diversification after ranking.

Ensure variation across:

primary ingredient
cuisine
preparation method

where possible.

---

# 146. NUTRITION ENGINE

Canonical nutrient units must be normalized.

Store source.

Support:

per 100 g

and calculated serving.

Do not mix salt and sodium without explicit conversion logic.

---

# 147. EXPIRATION ENGINE

Structured rule model.

ExpirationRule:

food / food group
storage condition
opened status
min duration
typical duration
max duration
source
confidence
version

Never present theoretical maximum as safety guarantee.

---

# 148. SCIENTIFIC EVIDENCE DATA MODEL

ScientificSource:

id
authority
title
url
date
jurisdiction
source\_type
retrieved\_at

ScientificClaim:

subject
claim\_type
summary
evidence\_strength
review\_status
valid\_from
valid\_to

---

# 149. RECALL DATA

FoodRecall:

authority
title
published\_at
product\_name
brand
barcode optional
batch optional
region
risk\_summary
source\_url
status

---

# 150. FILE UPLOAD SECURITY

Image validation:

MIME type
file size
pixel dimensions

Random storage path.

No trust in extension.

Use signed URLs where appropriate.

---

# 151. IMAGE RETENTION

Raw food/receipt images should have limited retention.

Prefer deleting raw images after processing unless user explicitly needs them.

Document retention.

---

# 152. PRIVACY

Build GDPR-compatible functionality from architecture level.

Provide:

privacy notice
consent management
data export
account deletion
data deletion
consent versioning

---

# 153. HEALTH-RELATED DATA

Diet associated with medical conditions, allergy information and similar data require additional privacy consideration.

Store only information necessary for user-requested functionality.

Do not use health-related profile information for advertising.

---

# 154. CONSENT

Maintain:

ConsentRecord

type
version
accepted\_at
withdrawn\_at optional

---

# 155. DATA EXPORT

Allow export of:

profile
diet configuration
inventory
meal plans
shopping history where retained
saved recipes
waste history

Prefer JSON + optional CSV.

---

# 156. ACCOUNT DELETION

Handle:

authentication account
profile
personal storage
personal health-related data
household relationship
subscription

Shared household records require ownership-aware deletion logic.

---

# 157. SECURITY

Apply:

least privilege
TLS
secret separation
rate limiting
input validation
secure storage
dependency updates
authorization checks
secure session handling

---

# 158. LOGGING

Never log:

passwords
access tokens
service-role keys

Minimize logging of:

allergies
medical nutrition profile
personal nutrition data.

---

# 159. OBSERVABILITY

Backend:

structured logs
request IDs
error tracking
latency
job metrics

Mobile:

crash reporting
network failures

Admin:

audit history.

---

# 160. FEATURE FLAGS

Implement feature flags.

Examples:

AI\_MULTI\_SCAN
RECEIPT\_SCAN
MEAL\_PLANNER
HOUSEHOLD
FOOD\_RECALLS
RECIPE\_IMPORT
PREMIUM
VOICE\_COOKING

---

# 161. OFFLINE MODE

Cache locally:

inventory
profile essentials
recent recipes
shopping list
meal plan

Allow viewing and reasonable editing offline.

Queue safe operations.

Synchronize when connection returns.

---

# 162. CONFLICT MANAGEMENT

For household quantities:

prevent negative quantities.

Use backend transactions.

Handle concurrent edits.

---

# 163. PERFORMANCE

Optimize:

startup
scroll performance
image caching
pagination
database indexes
API payload size

Avoid loading full nutrition records in every fridge row.

---

# 164. ACCESSIBILITY

Support:

VoiceOver
TalkBack
dynamic font sizes
adequate contrast
large touch targets
reduced motion

Never communicate expiration only through color.

---

# 165. EMPTY STATES

Fridge:

“Nothing here yet.”

CTA:

Add food.

ChefTable:

If inventory empty:

“Add a few foods and EatMe can start cooking with you.”

HealthyFood:

“Scan or search a food.”

---

# 166. ERROR STATES

Every async view must handle:

loading
success
empty
offline
error

No blank UI.

---

# 167. MONETIZATION

Prepare freemium architecture.

Do not hard-code plan pricing.

Possible:

Free

EatMe+

---

# 168. FREE PLAN CONCEPT

Potential features:

manual inventory
barcode scanning
basic recipe recommendations
basic HealthyFood
limited AI scans

---

# 169. EATME+ CONCEPT

Possible:

unlimited/more AI scans
receipt scanning
advanced meal planning
household
advanced nutrition insights
diet personalization
history analytics
recipe import
cost/waste insights

Product owner decides exact paywall later.

---

# 170. ENTITLEMENT SYSTEM

Do not scatter:

`if premium`

throughout code.

Create capability-based entitlements.

Example:

CAN\_SCAN\_RECEIPTS
CAN\_USE\_HOUSEHOLD
AI\_SCAN\_MONTHLY\_LIMIT

---

# 171. ANALYTICS

Track privacy-conscious events.

Examples:

signup\_completed
onboarding\_completed
food\_added
barcode\_scan
multi\_food\_scan
receipt\_import
recipe\_recommended
recipe\_opened
recipe\_cooked
recipe\_feedback
food\_discarded
shopping\_list\_created
diet\_changed

Do not send medical condition labels to generic analytics platforms.

---

# 172. PRODUCT KPIs

Prepare analytics to measure:

D1 retention
D7 retention
D30 retention
weekly active users
recipes cooked per active user
foods added
inventory accuracy proxy
AI scan confirmation rate
food saved before expiry
receipt scan usage
shopping list conversion
average time from recommendation to cook
household activation

---

# 173. NORTH STAR METRIC

Candidate:

**Useful meals prepared through EatMe per active household per week.**

Secondary:

food items saved from waste.

---

# 174. REPOSITORY WORKFLOW

Use:

main

as protected release branch.

Branches:

feat/...
fix/...
chore/...
refactor/...

Use short-lived branches.

---

# 175. COMMITS

Prefer Conventional Commits.

Examples:

feat(fridge): add inventory batches

feat(diet): implement versioned rule engine

fix(allergy): prevent substitution conflict

test(recommender): add hard constraint cases

---

# 176. PULL REQUESTS

Every PR includes:

Summary
Why
Implementation
Screenshots when UI changes
Tests
Database migrations
Security impact
Diet/medical nutrition impact
Known limitations

---

# 177. GITHUB ISSUES

Create issue templates:

Bug
Feature
Technical debt
Scientific content update
Diet rule update
Security issue process reference

---

# 178. MILESTONES

Create GitHub milestones:

Foundation

Core MVP

AI Inventory

HealthyFood

Scientific Evidence

Meal Planning

Household

Beta

1.0

---

# 179. CI MOBILE

On PR:

install Flutter

dependency restore

format validation

static analysis

unit tests

widget tests

integration tests where feasible

Android build

iOS build where runner supports it.

---

# 180. CI BACKEND

Run:

format/lint

type checking

unit tests

integration tests

migration validation

Docker build

security checks.

---

# 181. ADMIN CI

Run:

lint
typecheck
tests
production build.

---

# 182. DEPENDENCY MANAGEMENT

Configure Dependabot or equivalent.

Run dependency vulnerability scans.

---

# 183. CODEQL / SECURITY SCANNING

Enable where available.

No credentials committed.

---

# 184. ENVIRONMENTS

Maintain:

development
staging
production

Separate:

database
storage
AI keys
OAuth settings
notifications
monitoring

---

# 185. .ENV

Provide:

`.env.example`

with variable names only.

Never commit working secrets.

---

# 186. DOCUMENTATION

Create:

README.md

docs/product/product-overview\.md

docs/architecture/system-overview\.md

docs/architecture/data-model.md

docs/diet-engine/overview\.md

docs/ai/overview\.md

docs/evidence/overview\.md

docs/security/security-model.md

docs/privacy/privacy-architecture.md

docs/releases/release-process.md

---

# 187. ADR

Create Architecture Decision Records.

At least:

Flutter

Supabase/PostgreSQL

FastAPI

state management

offline persistence

diet rule engine

recommendation architecture

AI provider abstraction

scientific RAG

background processing

---

# 188. README QUALITY

README must allow a new developer to:

clone repository

configure environment

start database

run backend

run admin

run mobile

seed test data

run tests

without undocumented tribal knowledge.

---

# 189. IMPLEMENTATION STATUS

Maintain:

`docs/product/implementation-status.md`

Sections:

Done
In progress
Next
Blocked
Known technical debt

Update it with every significant implementation milestone.

---

# 190. TESTING

Required:

unit tests
widget tests
API tests
database tests
RLS tests
integration tests
critical E2E tests
visual/golden tests

---

# 191. CRITICAL ALLERGY TEST

Given:

User allergy = peanut.

Recipe contains peanut.

Expected:

recipe rejected before ranking.

No AI override possible.

---

# 192. UNKNOWN INGREDIENT SAFETY TEST

If an ingredient cannot be confidently identified:

EatMe must not state:

“Safe for your allergy.”

Use:

“Unable to fully verify compatibility.”

---

# 193. DIET TESTS

Test:

single diet

multiple diets

strict diet

flexible diet

conflicting profiles

medical hard constraint

version changes

deprecated rules.

---

# 194. RAD TEST

Ensure:

RAD profile can be selected when published.

Rules derive from DietRule database.

No RAD-specific clinical logic is hard-coded in Flutter or generic AI prompts.

Unpublished rules must not influence user recommendations.

---

# 195. INVENTORY TESTS

Test:

add
consume
batch
merge
separate expiration
open product
discard
concurrent update
offline sync

---

# 196. AI TESTS

Test:

valid output

invalid JSON

missing fields

low confidence

provider failure

timeout

incorrect food candidate

confirmation required.

---

# 197. RECEIPT TESTS

Test:

unclear receipt

duplicate line

weight-based produce

abbreviated names

missing date

multiple tax lines

unknown item.

---

# 198. EXPIRATION TESTS

Test:

use-by

best-before

estimated date

opened product

timezone

manual override

missing date.

---

# 199. RECOMMENDATION TESTS

Ensure:

hard constraints always precede score.

Validate ranking modes:

default

clear fridge

no shopping

quick

health first.

---

# 200. E2E MVP TEST

Automate:

launch

→ signup

→ onboarding

→ choose diet

→ add allergy

→ add food

→ open ChefTable

→ recommendation

→ recipe details

→ cook

→ inventory update

→ save leftover.

---

# 201. SECOND E2E

Barcode

→ product recognition

→ add fridge

→ HealthyFood

→ personalized compatibility.

---

# 202. THIRD E2E

Multi-photo scan

→ async processing

→ confidence results

→ user corrections

→ inventory commit.

---

# 203. DEVELOPMENT PHASE 0

Repository foundation.

Implement:

monorepo

CI

Flutter shell

backend shell

database

admin shell

authentication skeleton

theme

design system.

---

# 204. PHASE 1 — CORE VERTICAL SLICE

Build fully:

Authentication

Onboarding

Diet profiles

Allergy/intolerance

Manual inventory

Fridge

ChefTable

Recipe

Cook flow

Inventory consumption

Profile

Light/dark mode.

Do not start 20 advanced features before this works end-to-end.

---

# 205. PHASE 2 — SMART INVENTORY

Barcode scanning

Product lookup

Multi-product photo

OCR

Expiration estimation

Inventory confirmation

Receipt scanning.

---

# 206. PHASE 3 — PERSONALIZATION

Recipe feedback

Behavioral learning

Recommendation ranking modes

Leftovers

Cuisine personalization.

---

# 207. PHASE 4 — HEALTHYFOOD

Nutrition

For You analysis

Diet compatibility

Ingredient analysis

Allergens.

---

# 208. PHASE 5 — SCIENTIFIC INTELLIGENCE

Evidence database

RAG

Scientific source UI

Food safety alerts

Recall architecture

Admin review.

---

# 209. PHASE 6 — PLANNING

Meal Planner

Shopping List

Weekly nutrition

Shopping prediction

Recipe import.

---

# 210. PHASE 7 — HOUSEHOLD

Invitations

Shared inventory

Household restrictions

Realtime sync.

---

# 211. PHASE 8 — BUSINESS

Entitlements

Subscription-ready design

Analytics

Waste/cost insights

Beta hardening.

---

# 212. DEFINITION OF DONE

A feature is NOT complete if only the UI exists.

A feature is done only when applicable:

frontend complete

backend complete

database complete

security implemented

error/loading/empty states

light/dark mode

tests

analytics

documentation

accessibility

no dummy button.

---

# 213. NO FAKE FEATURES

Never implement a production button that does nothing.

Incomplete features should be:

feature flagged

or hidden.

Do not simulate scientific analysis when the evidence service did not run.

Do not simulate AI recognition when the AI provider was unavailable.

---

# 214. MOCK PROVIDERS

Mocks are allowed for local development.

They must:

implement production interfaces;

be clearly named;

never activate in production configuration.

---

# 215. CODING AGENT OPERATING RULES

When this prompt is provided inside a GitHub repository:

FIRST:

inspect all files.

Do not immediately overwrite the repository.

Determine whether existing code can be reused.

Then:

create/update implementation plan.

---

# 216. GITHUB EXECUTION BEHAVIOR

Work incrementally.

For each meaningful implementation slice:

create or use appropriate branch;

implement;

test;

commit;

prepare PR-quality changes.

Do not combine hundreds of unrelated modifications into one impossible-to-review change unless explicitly operating in a bootstrap phase.

---

# 217. DO NOT ASK UNNECESSARY QUESTIONS

Do not ask the product owner whether to use:

one reasonable library vs another;

minor folder naming;

ordinary code style choices.

Use engineering judgment.

Document major decisions.

---

# 218. WHEN CREDENTIALS ARE MISSING

Do not stop implementation.

Create:

provider interface

development mock

environment variable definition

setup documentation

and continue all work that does not require the credential.

Mark integration as blocked only at final live-credential step.

---

# 219. NO UNSAFE SCIENTIFIC PLACEHOLDERS

Never invent medical or nutritional science merely to populate the demo.

Use synthetic/demo records clearly marked as demo.

If real scientific content has not been validated:

leave production record unpublished.

---

# 220. MINIMAL DESIGN ENFORCEMENT

During UI implementation review every screen against:

Can something be removed?

Can secondary content be hidden behind detail?

Are there more than two primary visual actions?

Are there too many badges?

Is nutritional information overwhelming the food experience?

Would a normal person understand the screen in three seconds?

If not:

simplify.

---

# 221. CHEFTABLE VISUAL TARGET

ChefTable should ideally display on first viewport:

Greeting

3 foods to use soon

1 main recipe

possibly beginning of second recommendation.

Not 10 cards.

---

# 222. FRIDGE VISUAL TARGET

Fridge should primarily feel like:

a clean list of what I own.

Not an Excel spreadsheet.

---

# 223. HEALTHYFOOD VISUAL TARGET

HealthyFood first answers:

“How does this fit me?”

Detailed biochemistry belongs lower in the page.

---

# 224. PROFILE VISUAL TARGET

Profile should use grouped clean rows.

Avoid displaying the entire Diet Knowledge Base directly.

---

# 225. MICROCOPY

EatMe's tone:

friendly

short

calm

helpful

nonjudgmental.

Never:

“You failed your diet.”

Prefer:

“This meal is less aligned with your current profile.”

---

# 226. FOOD WASTE COPY

Never shame users.

Prefer:

“You saved 5 foods this week.”

Not:

“You wasted too much food.”

---

# 227. SAFETY COPY

Safety is the exception.

Be clear.

Example:

“Contains peanut according to the product ingredient list.”

No euphemisms.

---

# 228. POSSIBLE FUTURE HEALTH INTEGRATION

Architect but do not initially activate:

Apple Health / HealthKit

Android Health Connect.

Potential future use:

activity-aware energy targets

nutrition logging

weight trend

but only after explicit user activation and product/legal review.

---

# 229. FUTURE SMART SCALE

Allow future inventory integration with kitchen scales.

Do not implement before core product.

---

# 230. FUTURE SMART FRIDGE

Do not couple architecture in a way that prevents IoT inventory sources.

Potential:

camera fridge

smart appliance integrations.

---

# 231. FUTURE EAT-OUT MODE

Potential future feature:

scan restaurant menu

→ show compatibility

→ suggest choices.

Not part of initial roadmap.

---

# 232. FUTURE PLATE ANALYSIS

Photo meal

→ identify foods

→ estimate nutrition.

Do not prioritize before pantry and recommendation loop is successful.

---

# 233. PRODUCT VALUE PRIORITY

If resources are limited, prioritize features in this order:

1. frictionless inventory;
2. expiration awareness;
3. personalized recipe recommendation;
4. diet/allergy intelligence;
5. cooking-to-inventory loop;
6. receipt scan;
7. HealthyFood;
8. shopping;
9. leftovers;
10. household;
11. advanced analytics.

---

# 234. CRITICAL PRODUCT RISKS

Continuously monitor:

users stop updating inventory

AI scan errors

incorrect expiration estimates

unsafe diet interpretation

recipe repetition

notification fatigue

high AI operating cost

slow onboarding

overly complicated UI

insufficient food database coverage.

---

# 235. SOLUTION TO INVENTORY ABANDONMENT

Reduce manual maintenance using:

receipt scan

barcode

multi-food scan

recipe consumption update

household synchronization

predicted depletion

quick consume gestures.

This problem is strategically critical.

---

# 236. QUICK CONSUME

Allow swipe/quick action:

Consumed

for food items.

Then quantity adjustment only if needed.

---

# 237. SMART DEPLETION

For recurring stable products, EatMe may estimate depletion.

But never silently remove inventory based purely on prediction.

Ask:

“Is the milk finished?”

---

# 238. WEEKLY INVENTORY CHECK

Optional low-frequency reminder:

“Quick fridge check?”

Show uncertain or old inventory records.

User can confirm/remove them rapidly.

This prevents database drift.

---

# 239. TRUST MODEL

EatMe should distinguish:

Confirmed

Estimated

Possibly outdated

for inventory knowledge.

Internal inventory confidence can drive reminders.

---

# 240. INVENTORY CONFIDENCE

Potential calculated indicator based on:

data source

last confirmation

expected consumption

expiration

manual corrections.

Do not expose complexity unless useful.

---

# 241. DATA QUALITY FEEDBACK

Allow:

Report wrong product

Wrong nutrition information

Wrong ingredient

Wrong diet compatibility

Wrong expiration estimate

This should feed admin review.

---

# 242. BETA FEATURE TELEMETRY

Track corrections after AI scans.

Important metric:

AI recognized

vs

user corrected.

Use to improve scanning models.

---

# 243. PRIVACY-FRIENDLY LEARNING

Personalization should be user-account-specific.

Avoid unnecessary centralized storage of sensitive behavior.

Document what data feeds learning.

---

# 244. APP STARTUP

Startup should not wait for expensive recommendation generation.

Display cached ChefTable immediately.

Refresh asynchronously.

---

# 245. CACHE STRATEGY

Cache:

user profile

inventory

recipe images

latest recommendations

diet definitions

shopping list.

Invalidate intelligently.

---

# 246. API FAILURE UX

If recommendation server unavailable:

show recent recommendations

and allow fridge access.

Never block application.

---

# 247. DATABASE MIGRATIONS

All schema changes require version-controlled migrations.

Never modify production schema manually without migration.

---

# 248. SEED DATA

Development seed must include:

foods

products

recipes

diet definitions

diet rules

allergens

expiration rules

inventory demo

scientific demo references where valid.

---

# 249. DEMO PROFILE

Create fictional demo user.

Example:

2-person household

Mediterranean

High Protein

example intolerance

mixed fridge

three expiring foods.

Do not use actual personal data.

---

# 250. BUILD QUALITY

Code should be:

strongly typed

modular

testable

documented where logic is non-obvious

free from dead placeholder components.

---

# 251. MOBILE ARCHITECTURE

Preferred structure:

lib/
app/
core/
design\_system/
features/
auth/
onboarding/
chef\_table/
fridge/
food\_scan/
healthy\_food/
diet/
recipe/
cooking/
shopping/
meal\_plan/
household/
profile/

Within complex features:

data/
domain/
presentation/

Avoid architecture ceremony for trivial components.

---

# 252. STATE MANAGEMENT

Use Riverpod consistently.

Do not mix:

Bloc

Provider

Redux

Riverpod

without necessity.

---

# 253. ROUTING

Use typed/structured GoRouter routes.

Deep-link-ready for:

recipe

product

household invite.

---

# 254. ADMIN AUTHORIZATION

Admin application requires separate roles.

Example:

support

content\_editor

scientific\_reviewer

admin

superadmin.

Diet publication should require appropriate permission.

---

# 255. AUDIT TRAIL

Audit changes to:

diet rules

allergy mappings

scientific claims

expiration rules

product ingredient corrections.

---

# 256. RELEASE TARGET

Prepare eventually for:

Apple App Store

Google Play Store.

Include:

icons

splash

privacy manifest requirements as applicable

permission copy

release signing documentation

TestFlight process

internal Play testing process.

---

# 257. VERSIONING

Use semantic app versions.

Maintain CHANGELOG.

---

# 258. CRASH-FREE TARGET

Instrumentation should allow monitoring:

crash-free users

API failures

scan failures

recommendation errors.

---

# 259. PERFORMANCE TARGETS

Aim for:

smooth 60 fps interaction

fast startup

responsive lists

immediate local inventory operations

reasonable upload compression

background AI processing.

---

# 260. FINAL IMPLEMENTATION OUTPUT

When implementation work is completed for any milestone, report:

Implemented features

Files changed

Database migrations

Tests added

Commands run

Known limitations

Security implications

Scientific/diet implications

Remaining blockers

Next recommended task.

---

# 261. DO NOT CLAIM SUCCESS WITHOUT VERIFICATION

Never state:

“Everything works”

unless tests/builds support the claim.

If iOS build cannot be tested due to environment:

state that explicitly.

---

# 262. FIRST ENGINEERING TASK

If repository is empty:

bootstrap the monorepo.

Create:

README

architecture documentation

Flutter app

FastAPI app

database project

admin app

CI

design tokens

environment templates.

Then implement the first vertical slice.

---

# 263. FIRST VERTICAL SLICE

Must become fully functional before expanding substantially:

Launch

→ registration/login

→ onboarding

→ select Mediterranean diet

→ optional additional diet

→ allergy configuration

→ manually add food

→ view Fridge

→ ChefTable recommendation

→ open recipe

→ cook recipe

→ confirm ingredient consumption

→ Fridge quantities updated.

---

# 264. SECOND VERTICAL SLICE

Barcode

→ product lookup

→ confirmation

→ Fridge

→ HealthyFood.

---

# 265. THIRD VERTICAL SLICE

Photograph multiple products

→ asynchronous AI analysis

→ recognized products

→ confidence display

→ corrections

→ confirmation

→ inventory update.

---

# 266. FOURTH VERTICAL SLICE

Receipt scan

→ line extraction

→ confirmation

→ inventory

→ shopping cost information.

---

# 267. FIFTH VERTICAL SLICE

Meal plan

→ missing foods

→ shopping list

→ recipe cooking

→ pantry update

→ leftovers.

---

# 268. ARCHITECTURAL RULE

Prefer a smaller number of fully functioning vertical slices to a large number of disconnected screens.

---

# 269. FINAL PRODUCT STANDARD

EatMe must eventually feel as if one intelligent system understands:

what food is available;

what is going to expire;

who is eating;

what they can eat;

what they like;

what they want to achieve;

how long they have to cook;

whether they want to shop;

what they have recently eaten;

and what information is scientifically reliable.

The user should experience that complexity through an interface that feels extremely simple.

The best EatMe experience is:

**complex intelligence behind a minimal interface.**

That principle should guide every implementation decision.