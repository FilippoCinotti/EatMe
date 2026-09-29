"""Build the hero-image prompt for one recipe from its real EatMe data.

The prompt is assembled from the recipe title, its curated visual description
(``image_prompt``, written from the full source recipe), the canonical
ingredients ranked by weight, the cooking method found in the steps and the
final serving step. A fixed art-direction block keeps the whole catalog
consistent. FLUX.1-schnell reads at most 256 T5 tokens, so the recipe-specific
part comes first and the text is kept under ``MAX_PROMPT_CHARS``.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

PROMPT_VERSION = 'eatme-hero-v1'
MAX_PROMPT_CHARS = 900
MAX_CLIP_CHARS = 300   # FLUX's CLIP encoder reads 77 tokens; it gets a short summary, T5 the full prompt

# The same art direction for every recipe: one editorial collection.
ART_DIRECTION = (
    'Realistic premium editorial food photography: soft natural side window light, 35-degree angle, '
    'subtle shallow depth of field, minimal warm neutral stone surface, contemporary tableware, dish centred '
    'with space around it, natural colours.'
)
EXCLUSIONS = (
    'Finished plated dish only; no raw ingredient spread, collage, cooking scene, text, labels, packaging, '
    'logos, watermark, people or hands.'
)
# Clauses of a curated description that set camera, light or scenery: the art
# direction decides those so every image belongs to one collection.
SCENE_CLAUSE = re.compile(r'photograph|\bview\b|angle|\blight\b|lighting|overhead|close[- ]up|\bshot\b|outdoor|'
                          r'\btable\b|background|backdrop|rustic|studio|from above', re.I)
SCENE_PHRASES = [re.compile(p, re.I) for p in (
    r',?\s*\b(?:photographed|shot|captured)\b[^,;]*',
    r',?\s*\b(?:in|under|with)\s+(?:soft|warm|bright|golden|gentle|natural|window|morning|day)'
    r'(?:\s+(?:soft|warm|bright|golden|natural|window))*\s*(?:day)?light\b',
    r',?\s*\b(?:overhead|top-down|3/4|three-quarter|side|close-up)\s+(?:view|angle|shot)\b',
    r',?\s*\bon\s+an?\s+(?:rustic\s+|wooden\s+|marble\s+|white\s+|dark\s+)*table\b',
    r',?\s*\boutdoors\b',
)]

# Ingredients that are rarely visible in a finished dish (seasoning, leavening,
# cooking fat, liquids absorbed during cooking).
INVISIBLE = {
    'salt', 'black-pepper', 'white-pepper', 'water', 'olive-oil', 'extra-virgin-olive-oil', 'sunflower-oil',
    'vegetable-oil', 'seed-oil', 'peanut-oil', 'rapeseed-oil', 'baking-powder', 'baking-soda', 'yeast',
    'brewers-yeast', 'dry-yeast', 'vanilla', 'vanilla-extract', 'gelatin', 'cornstarch', 'potato-starch',
    'vinegar', 'white-wine-vinegar', 'apple-cider-vinegar', 'stock', 'vegetable-stock', 'chicken-stock',
}
# Garnishes image models like to invent; excluded explicitly when the recipe does not use them.
GARNISH_WATCH = [
    ('parsley', ('parsley',)), ('basil', ('basil',)), ('coriander', ('coriander', 'cilantro')),
    ('mint', ('mint',)), ('cream', ('cream',)), ('tomato', ('tomato',)), ('lemon wedges', ('lemon',)),
    ('rocket', ('rocket', 'arugula')), ('sesame seeds', ('sesame',)), ('chilli', ('chilli', 'chili')),
]

# (pattern on the English title, dish type, serving direction); first match wins.
DISH_TYPES = [
    (r'smoothie|milkshake|shake\b|lassi|frapp|latte|juice|lemonade|cocktail|hot chocolate|water$|infusion$|'
     r'infused water|tea$|iced tea|coffee$|iced coffee|syrup$|cordial|punch$|spritz|sangria', 'drink',
     'served in a clear glass'),
    (r'soup|broth|chowder|bisque|minestr|ramen|pho\b|gazpacho|velout', 'soup', 'served in a wide bowl'),
    (r'lasagn|cannelloni|pasta bake|moussaka|gratin|parmigiana|casserole', 'baked dish',
     'one neat portion on a plate, the baking dish softly behind'),
    (r'risotto|paella|pilaf|pilau|biryani', 'rice dish', 'served in a shallow bowl'),
    (r'spaghetti|linguine|tagliatelle|penne|rigatoni|fusilli|pappardelle|orecchiette|gnocchi|'
     r'carbonara|pasta|noodle|udon|ravioli|tortellini|mac and cheese|orzo', 'pasta or noodles',
     'served in a shallow bowl'),
    (r'stir[- ]?fr(?:y|ied)|wok\b', 'stir-fry', 'served in a bowl'),
    (r'curry|stew|chilli|chili|tagine|dal\b|dhal|goulash|ragu|ragù|casserole', 'stew or curry',
     'served in a bowl'),
    (r'yorkshire pudding', 'savoury bake', 'served on a plate'),
    (r'(?:rice|lunch|buddha|grain|noodle|burrito|power|breakfast) bowl|poke', 'bowl', 'served in a deep bowl'),
    (r'salad|slaw|tabbouleh', 'salad', 'served in a shallow bowl or on a plate'),
    (r'pizza\b|pizzas\b|focaccia|flatbread|bruschett|crostini|toast\b|on toast', 'bread-based dish',
     'served on a board or plate'),
    (r'burger|sandwich|toastie|wrap|panini|piadin|bagel|tacos?|burrito|quesadilla|pitta|pita', 'hand-held dish',
     'served on a plate'),
    (r'pancake|waffle|french toast|crêpe|crepe', 'breakfast stack', 'stacked on a plate'),
    (r'porridge|oats|granola|muesli|chia|yogh?urt bowl|acai|bircher', 'breakfast bowl', 'served in a bowl'),
    (r'ice cream|gelato|sorbet|semifreddo|granita|frozen yogh?urt', 'frozen dessert',
     'scoops in a small bowl or glass'),
    (r'mousse|pudding|panna cotta|tiramis|trifle|cheesecake pot|posset|custard|budino', 'spoon dessert',
     'in an individual glass or dish'),
    (r'cookie|biscuit|brownie|blondie|flapjack|bars?\b|muffin|cupcake|scone|macaron|energy ball|bites\b|'
     r'truffle|fudge', 'small bakes', 'a few pieces arranged on a plate'),
    (r'cake|torta|loaf|banana bread|traybake|swiss roll|gateau|sponge|cheesecake', 'cake',
     'one slice on a plate with the rest of the cake behind'),
    (r'\bpie\b|tart|quiche|crostata|galette|strudel|pastry', 'pie or tart', 'one slice on a plate, the rest behind'),
    (r'omelette|frittata|shakshuka|eggs?\b|scrambled', 'egg dish', 'served in the pan or on a plate'),
    (r'^(?!.*\b(?:in|with|on|and)\b).*(?:sauce|b[ée]chamel|dressing|gravy|marmalade|jam|compote|chutney|relish|pickles?|preserves?|'
     r'in oil|sott.?olio|butter|aioli|mayonnaise|mayo|ketchup|mustard|salsa verde)$', 'condiment', 'in a small bowl or jar with a spoon'),
    (r'dip\b|hummus|guacamole|salsa|tzatziki|pesto|spread|pâté|pate', 'dip', 'in a small bowl'),
]
METHODS = [
    (r'\b(bake|baked|roast|roasted|oven)\b', 'oven-baked with golden edges'),
    (r'\b(grill|grilled|griddle|barbecue|bbq|chargrill)', 'with light char marks'),
    (r'\b(deep[- ]fry|deep[- ]fried|fry until crisp|golden and crisp|crispy)\b', 'crisp and golden'),
    (r'\b(simmer|braise|slow[- ]cook|stew)\b', 'slow-cooked and glossy'),
    (r'\b(steam|steamed)\b', 'gently steamed'),
    (r'\b(freeze|frozen|chill|refrigerate|set in the fridge)\b', 'chilled and set'),
]
HEAT = re.compile(r'\b(bake|roast|oven|grill|fry|fried|boil|simmer|cook|saut|toast|heat|steam|brown|sear|poach|'
                  r'microwave|melt)', re.I)
SERVE = re.compile(r'\b(serve|serving|garnish|top with|topped|sprinkle|scatter|drizzle|dust|decorate|finish with)',
                   re.I)


@dataclass
class PromptSpec:
    text: str
    dish_type: str
    short: str = ''
    main_ingredients: list = field(default_factory=list)
    style_notes: list = field(default_factory=list)
    excluded_garnish: list = field(default_factory=list)
    version: str = PROMPT_VERSION


def food_name(food):
    name = food.get('name') if isinstance(food.get('name'), dict) else None
    return ((name or {}).get('en') or food.get('name_en') or food.get('slug', '')).strip()


def _english(value):
    if isinstance(value, dict):
        return (value.get('en') or value.get('it') or '').strip()
    return str(value or '').strip()


def _steps(recipe):
    steps = recipe.get('steps') or {}
    items = (steps.get('en') or steps.get('it') or []) if isinstance(steps, dict) else steps
    return [(s.get('text') if isinstance(s, dict) else str(s)).strip() for s in items if s]


def _sentence(text, words):
    text = re.sub(r'\s+', ' ', text).strip().rstrip('.')
    parts = text.split(' ')
    return ' '.join(parts[:words]) + ('…' if len(parts) > words else '')


def dish_description(recipe):
    """The curated visual description without camera, light or scenery clauses."""
    text = re.sub(r'\s+', ' ', (recipe.get('image_prompt') or '')).strip().rstrip('.')
    for pattern in SCENE_PHRASES:
        text = pattern.sub('', text)
    clauses = [c.strip() for c in re.split(r',\s*|;\s*', text) if c.strip()]
    kept = [c for c in clauses if not SCENE_CLAUSE.search(c)]
    # A clause such as "in natural light" can also trail the last kept clause.
    description = ', '.join(kept)
    return description[:1].upper() + description[1:]


def dish_type(recipe):
    title = re.sub(r'[()\[\]]', ' ', _english(recipe.get('title')).lower()).strip()
    for pattern, label, serving in DISH_TYPES:
        # Terms must start a word ("ragu" must not match "asparagus") but may be word stems ("minestr").
        if re.search(rf'(?<![a-z])(?:{pattern})', title):
            return label, serving
    meals = set(recipe.get('meal_types') or [])
    if 'merenda' in meals and not meals & {'lunch', 'dinner'}:
        return 'sweet snack', 'served on a small plate'
    return 'savoury dish', 'plated on a ceramic plate'


def main_ingredients(recipe, foods, limit=6):
    ranked = []
    for item in recipe.get('ingredients') or []:
        food = foods.get(item.get('food_id')) or {}
        slug = food.get('slug', '')
        if not food or slug in INVISIBLE:
            continue
        ranked.append((float(item.get('grams') or 0), food_name(food).lower()))
    ranked.sort(key=lambda pair: -pair[0])
    names = []
    for _, name in ranked:
        if name and name not in names:
            names.append(name)
    return names[:limit]


def style_notes(recipe):
    steps = _steps(recipe)
    text = ' '.join(steps).lower()
    notes = [note for pattern, note in METHODS if re.search(pattern, text)][:2]
    if steps and not HEAT.search(text):
        notes.append('fresh, uncooked preparation')
    serving = next((s for s in reversed(steps) if SERVE.search(s)), '')
    if serving:
        notes.append('serving: ' + _sentence(serving, 22).lower())
    return notes


def excluded_garnish(recipe, foods, ingredient_names):
    haystack = ' '.join([*ingredient_names, *(foods.get(i.get('food_id'), {}).get('slug', '')
                                              for i in recipe.get('ingredients') or []),
                         *_steps(recipe), _english(recipe.get('title')), recipe.get('image_prompt') or '']).lower()
    extras = recipe.get('pantry_extras') or {}
    haystack += ' ' + ' '.join((extras.get('en') or []) if isinstance(extras, dict) else []).lower()
    # Whole words only: "creamy sauce" does not mean the recipe uses cream.
    return [label for label, words in GARNISH_WATCH
            if not any(re.search(rf'\b{w}(?:e?s)?\b', haystack) for w in words)][:6]


def build_prompt(recipe, foods):
    """Return the prompt for ``recipe``; ``foods`` maps food_id to food data."""
    title = _english(recipe.get('title')) or recipe.get('slug', 'dish')
    kind, serving = dish_type(recipe)
    ingredients = main_ingredients(recipe, foods)
    notes = style_notes(recipe)
    garnish = excluded_garnish(recipe, foods, ingredients)
    cuisine = (recipe.get('cuisine') or '').replace('_', ' ').strip()
    description = dish_description(recipe)

    head = f'Editorial food photograph of the finished dish "{title}"'
    if cuisine and cuisine != 'other':
        head += f', {cuisine} cuisine'
    parts = [head + f', {kind}, {serving}.']
    optional = []
    if description:
        optional.append(description + '.')
    if ingredients:
        optional.append('Ingredients: ' + ', '.join(ingredients) + '.')
    if notes:
        optional.append('Style: ' + '; '.join(notes) + '.')
    tail = []
    if garnish:
        tail.append('Do not add ' + ', '.join(garnish) + ' or any ingredient not in the recipe.')
    else:
        tail.append('Do not add any ingredient that is not in the recipe.')
    tail += [ART_DIRECTION, EXCLUSIONS]

    # Drop the least important optional parts until the prompt fits the budget.
    while optional and len(' '.join(parts + optional + tail)) > MAX_PROMPT_CHARS:
        optional.pop()
    text = ' '.join(parts + optional + tail)
    if len(text) > MAX_PROMPT_CHARS:
        text = ' '.join(parts + tail)
    short = f'{title}, {kind} {serving}, realistic premium editorial food photograph, soft natural window light, ' \
            'minimal neutral background, no people, no text'
    if len(short) > MAX_CLIP_CHARS:
        short = f'{title[:120]}, {kind}, realistic editorial food photograph, soft natural light, no people, no text'
    return PromptSpec(text=text, dish_type=kind, main_ingredients=ingredients, style_notes=notes,
                      excluded_garnish=garnish, short=short)
