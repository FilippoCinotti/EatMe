"""Fictional development catalog and conservative, versioned profile rules.

Profiles are self-declared product settings.  A published rule set only controls
EatMe filtering; it is not a diagnosis, prescription, or treatment claim.
"""
from uuid import NAMESPACE_URL, uuid5

from .storage import Database, encode


def identifier(kind: str, slug: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"https://eatme.invalid/{kind}/{slug}"))


ALLERGENS = ["gluten", "crustaceans", "eggs", "fish", "peanut", "soy", "milk", "nuts",
             "wheat", "celery", "mustard", "sesame", "sulphites", "lupin", "molluscs",
             "almond", "hazelnut", "walnut", "cashew", "pecan", "brazil_nut", "pistachio", "macadamia"]

INTOLERANCES = ["lactose", "fructose", "sorbitol", "mannitol", "xylitol", "maltitol", "fructans", "gos"]
SENSITIVITIES = ["caffeine", "alcohol", "spicy_food", "histamine"]
MEDICAL_AWARENESS = ["ibs", "diabetes", "prediabetes", "renal", "hypertension", "hyperlipidemia", "gout", "gerd", "pku", "custom_clinician"]
ETHICAL_PREFERENCES = ["halal", "kosher", "no_pork", "no_beef", "no_lamb", "no_shellfish", "no_alcohol", "no_alcohol_cooking", "no_gelatin", "religious_vegetarian", "ethical_vegan", "hindu_no_beef", "jain"]


def seed_catalog(db: Database):
    food_rows = [
        ("tomato", "Pomodori", "Tomatoes", "vegetable", [], [], "g"),
        ("zucchini", "Zucchine", "Zucchini", "vegetable", [], [], "g"),
        ("spinach", "Spinaci", "Spinach", "vegetable", [], [], "g"),
        ("chickpea", "Ceci cotti", "Cooked chickpeas", "legume", [], [], "g"),
        ("rice", "Riso", "Rice", "grain", [], [], "g"),
        ("pasta", "Pasta di frumento", "Wheat pasta", "grain", ["gluten", "wheat"], [], "g"),
        ("olive-oil", "Olio di oliva", "Olive oil", "oil", [], [], "ml"),
        ("feta", "Feta", "Feta", "dairy", ["milk"], ["lactose"], "g"),
        ("chicken", "Petto di pollo", "Chicken breast", "meat", [], [], "g"),
        ("peanut", "Arachidi", "Peanuts", "legume", ["peanut"], [], "g"),
        ("egg", "Uova", "Eggs", "egg", ["eggs"], [], "pcs"),
        ("milk", "Latte", "Milk", "dairy", ["milk"], ["lactose"], "ml"),
    ]
    recipes = [
        ("sunny-bowl", "Bowl di ceci e pomodori", "Chickpea & tomato bowl", 15,
         [("chickpea", 300), ("tomato", 200), ("olive-oil", 20)],
         ["Sciacqua e scola i ceci già cotti.", "Taglia i pomodori e uniscili ai ceci.", "Condisci con l’olio, mescola e servi."],
         ["Rinse and drain the cooked chickpeas.", "Chop the tomatoes and combine with the chickpeas.", "Dress with olive oil, toss and serve."]),
        ("green-pasta", "Pasta verde alle zucchine", "Zucchini & spinach pasta", 25,
         [("pasta", 160), ("zucchini", 250), ("spinach", 100), ("olive-oil", 20)],
         ["Porta a bollore l’acqua e cuoci la pasta seguendo la confezione.", "Affetta le zucchine e cuocile in padella con l’olio finché tenere.", "Unisci gli spinaci e lasciali appassire.", "Scola la pasta, mescola con le verdure e servi."],
         ["Bring water to a boil and cook the pasta following the package instructions.", "Slice the zucchini and sauté in olive oil until tender.", "Add the spinach and cook until wilted.", "Drain the pasta, combine with the vegetables and serve."]),
        ("tomato-feta", "Pomodori, ceci e feta", "Tomato, chickpea & feta salad", 10,
         [("tomato", 300), ("chickpea", 200), ("feta", 100), ("olive-oil", 15)],
         ["Lava e taglia i pomodori.", "Scola i ceci già cotti e taglia la feta.", "Unisci gli ingredienti, condisci con l’olio e servi."],
         ["Wash and chop the tomatoes.", "Drain the cooked chickpeas and crumble the feta.", "Combine the ingredients, dress with olive oil and serve."]),
        ("spinach-rice", "Riso con spinaci e ceci", "Spinach & chickpea rice", 30,
         [("rice", 160), ("spinach", 200), ("chickpea", 200), ("olive-oil", 20)],
         ["Cuoci il riso seguendo le istruzioni sulla confezione.", "Cuoci gli spinaci con l’olio, poi aggiungi i ceci già cotti.", "Unisci il riso alle verdure e servi appena pronto."],
         ["Cook the rice following the package instructions.", "Cook the spinach in olive oil, then add the cooked chickpeas.", "Combine the rice with the vegetables and serve immediately."]),
    ]
    supported = [
        ("balanced", "Equilibrata", "Balanced", False, [],
         "A neutral profile with no additional food exclusions."),
        ("omnivore", "Onnivora", "Omnivore", False, [],
         "A neutral eating style with no additional food exclusions."),
        ("mediterranean", "Mediterranea", "Mediterranean", False,
         [{"type":"PREFER", "groups":["vegetable","legume"], "hard_constraint":False}],
         "Prioritises vegetables and legumes when compatible options are available."),
        ("vegetarian", "Vegetariana", "Vegetarian", False,
         [{"type":"EXCLUDE", "groups":["meat","fish"], "hard_constraint":False}],
         "Excludes meat and fish according to the selected strictness."),
        ("vegan", "Vegana", "Vegan", False,
         [{"type":"EXCLUDE", "groups":["meat","fish","dairy","egg","honey"], "hard_constraint":False}],
         "Excludes animal-derived catalog groups according to the selected strictness."),
        ("pescatarian", "Pescetariana", "Pescatarian", False,
         [{"type":"EXCLUDE", "groups":["meat"], "hard_constraint":False}],
         "Excludes meat while retaining fish according to the selected strictness."),
        ("flexitarian", "Flexitariana", "Flexitarian", False,
         [{"type":"PREFER", "groups":["vegetable","legume"], "hard_constraint":False}],
         "Prioritises plant foods without creating a hard meat exclusion."),
        ("plant-forward", "A prevalenza vegetale", "Plant-forward", False,
         [{"type":"PREFER", "groups":["vegetable","legume"], "hard_constraint":False}],
         "Prioritises plant foods without claiming a vegan diet."),
        ("low-carb", "Preferenza low-carb", "Low-carb preference", False, [],
         "Records a preference only; no carbohydrate threshold is inferred."),
        ("low-fat", "Preferenza low-fat", "Low-fat preference", False, [],
         "Records a preference only; no fat threshold is inferred."),
        ("high-protein", "Proteica", "High protein", False,
         [{"type":"PREFER", "groups":["legume","meat","fish","egg","dairy"], "hard_constraint":False}],
         "A ranking preference based on catalog food groups, not a nutrient target."),
        ("whole-food", "Alimenti poco processati", "Whole-food focused", False, [],
         "Records a preference only when processing metadata is unavailable."),
        ("gluten-free", "Senza glutine", "Gluten free", False,
         [{"type":"EXCLUDE", "allergens":["gluten"], "hard_constraint":True}],
         "Blocks foods catalogued as containing gluten."),
        ("celiac", "Celiachia", "Celiac", True,
         [{"type":"EXCLUDE", "allergens":["gluten"], "hard_constraint":True}],
         "A self-declared strict gluten exclusion using current catalog metadata."),
        ("rad", "RAD", "RAD", True,
         [{"type":"PREFER", "groups":["vegetable","legume"], "hard_constraint":False},
          {"type":"EXCLUDE", "food_ids":[identifier("food","pasta")], "hard_constraint":True}],
         "A self-declared, conservative RAD profile using only reviewed catalog-level rules."),
    ]
    unavailable = [
        ("low-sodium", "Povera di sodio", "Low sodium"),
        ("low-fodmap", "Low FODMAP", "Low FODMAP"),
        ("renal", "Nutrizione renale", "Renal nutrition"),
        ("diabetes", "Nutrizione e diabete", "Diabetes-oriented nutrition"),
    ]
    with db.transaction() as tx:
        for slug, it, en, group, allergens, intolerances, unit in food_rows:
            data = dict(id=identifier("food",slug), slug=slug, name={"it":it,"en":en}, group=group,
                        allergens=allergens, may_contain=[], intolerances=intolerances, unit=unit,
                        ingredient_status="known", nutrition=None, provenance="demo", is_demo=True)
            tx.execute("INSERT INTO foods(id,data) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data", (data["id"], encode(data)))
        for slug, it, en, minutes, ingredients, steps_it, steps_en in recipes:
            data = dict(id=identifier("recipe",slug), slug=slug, title={"it":it,"en":en}, minutes=minutes,
                        servings=2, cuisine="mediterranean", is_demo=True, provenance="eatme-original-demo",
                        ingredients=[{"food_id":identifier("food",f),"quantity":str(q)} for f,q in ingredients],
                        steps={"it":steps_it,"en":steps_en}, nutrition=None)
            tx.execute("INSERT INTO recipes(id,data) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data", (data["id"], encode(data)))
        for slug, it, en, medical, rules, description in supported:
            diet_id = identifier("diet",slug)
            data = dict(id=diet_id, slug=slug, name={"it":it,"en":en}, medical=medical, is_demo=True,
                        status="PUBLISHED", description=description, self_declared=True,
                        clinical_limitations="Product filtering profile; not medical advice or a safety guarantee.")
            tx.execute("INSERT INTO diet_definitions VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,data=excluded.data",(diet_id,slug,encode(data)))
            tx.execute("INSERT INTO diet_versions VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET diet_id=excluded.diet_id,version=excluded.version,status=excluded.status,effective_from=excluded.effective_from,effective_until=excluded.effective_until,rules=excluded.rules",
                       (identifier("diet-version",slug+"-1"),diet_id,1,"PUBLISHED","2026-01-01",None,encode(rules)))
        for slug,it,en in unavailable:
            data = dict(id=identifier("diet",slug), slug=slug, name={"it":it,"en":en}, medical=slug!="high-protein",
                        status="REQUIRES_REVIEW", is_demo=True, review_date=None,
                        context=None, description=None, evidence_references=[], evidence_quality=None,
                        clinical_limitations="Uncurated: not available for recommendations")
            tx.execute("INSERT INTO diet_definitions VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,data=excluded.data",(data["id"],slug,encode(data)))
