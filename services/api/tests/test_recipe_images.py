import io
import json
import random
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))

from recipe_images import lifecycle, pipeline  # noqa: E402
from recipe_images.optimize import ASSET_SIZE, InvalidImage, optimize, validate  # noqa: E402
from recipe_images.prompt import MAX_PROMPT_CHARS, build_prompt, dish_type  # noqa: E402
from recipe_images.providers import ProviderUnavailable  # noqa: E402
from recipe_images.storage import LocalStorage, SupabaseStorage  # noqa: E402
from recipe_images.stores import CatalogFileStore, MemoryStore  # noqa: E402

NOW = datetime(2026, 9, 29, 12, 0, tzinfo=timezone.utc)
FOODS = {
    "f-pasta": {"slug": "pasta", "name": {"en": "Pasta"}},
    "f-guanciale": {"slug": "pancetta", "name": {"en": "Pancetta"}},
    "f-pecorino": {"slug": "pecorino", "name": {"en": "Pecorino"}},
    "f-egg": {"slug": "egg", "name": {"en": "Eggs"}},
    "f-salt": {"slug": "salt", "name": {"en": "Salt"}},
}


def recipe(n, **extra):
    data = {
        "id": f"00000000-0000-4000-8000-{n:012d}", "slug": f"recipe-{n}", "title": {"en": f"Carbonara {n}"},
        "cuisine": "italian", "meal_types": ["lunch", "dinner"],
        "ingredients": [{"food_id": "f-pasta", "grams": 400}, {"food_id": "f-guanciale", "grams": 150},
                        {"food_id": "f-pecorino", "grams": 100}, {"food_id": "f-egg", "grams": 110},
                        {"food_id": "f-salt", "grams": 5}],
        "steps": {"en": [{"text": "Fry the guanciale until crisp."},
                         {"text": "Toss the pasta with egg and pecorino, then serve topped with black pepper."}]},
        "image_prompt": "A shallow bowl of rigatoni in glossy egg and pecorino sauce, photographed at a 3/4 angle "
                        "on a rustic table in natural light.",
        "image_url": None,
    }
    data.update(extra)
    return data


class FakeProvider:
    name = "fake"

    def __init__(self, fail_for=(), unavailable=False, blank=False):
        self.fail_for, self.unavailable, self.blank, self.calls = set(fail_for), unavailable, blank, []
        self.short_prompts = []

    def check(self):
        if self.unavailable:
            raise ProviderUnavailable("no GPU")

    def generate(self, prompt, seed, width, height, short_prompt=None):
        self.calls.append((prompt, seed))
        self.short_prompts.append(short_prompt)
        if any(key in prompt for key in self.fail_for):
            raise RuntimeError("CUDA out of memory")
        if self.blank:
            return Image.new("RGB", (width, height), (240, 240, 240))
        rng = random.Random(seed)
        image = Image.new("RGB", (width // 8, height // 8))
        image.putdata([(rng.randrange(256), rng.randrange(256), rng.randrange(256))
                       for _ in range(image.width * image.height)])
        return image.resize((width, height), Image.Resampling.BICUBIC)

    def metadata(self):
        return {"provider": self.name, "model": "fake-model"}


class PromptTest(unittest.TestCase):
    def test_prompt_uses_real_recipe_data(self):
        spec = build_prompt(recipe(1), FOODS)
        self.assertIn('"Carbonara 1"', spec.text)
        self.assertIn("italian cuisine", spec.text)
        self.assertEqual(spec.main_ingredients, ["pasta", "pancetta", "eggs", "pecorino"])
        self.assertNotIn("salt", spec.main_ingredients)
        self.assertIn("rigatoni in glossy egg and pecorino sauce", spec.text)
        self.assertIn("serving: toss the pasta", spec.text)
        # Scene clauses of the curated description yield to the shared art direction.
        self.assertNotIn("rustic table", spec.text)
        self.assertIn("35-degree angle", spec.text)
        self.assertEqual(dish_type(recipe(1))[0], "pasta or noodles")

    def test_prompt_forbids_garnish_absent_from_the_recipe(self):
        spec = build_prompt(recipe(1), FOODS)
        self.assertIn("parsley", spec.excluded_garnish)
        self.assertIn("cream", spec.excluded_garnish)
        with_basil = recipe(2, steps={"en": [{"text": "Scatter basil leaves over the pasta and serve."}]})
        self.assertNotIn("basil", build_prompt(with_basil, FOODS).excluded_garnish)

    def test_prompt_without_curated_description_still_describes_the_dish(self):
        spec = build_prompt(recipe(3, image_prompt="", title={"en": "Beetroot soup"}), FOODS)
        self.assertIn("soup, served in a wide bowl", spec.text)
        self.assertIn("Ingredients: pasta, pancetta", spec.text)

    def test_every_catalog_prompt_fits_the_text_encoder_budget(self):
        store = CatalogFileStore(ROOT)
        foods = store.foods()
        for item in store.recipes():
            text = build_prompt(item, foods).text
            self.assertLessEqual(len(text), MAX_PROMPT_CHARS, item["slug"])
            self.assertIn("watermark, people or hands", text)


class LifecycleTest(unittest.TestCase):
    def test_missing_filter_and_protected_states(self):
        curated = frozenset({recipe(9)["id"]})
        states = {
            "missing": recipe(1),
            "legacy": recipe(2, image_url="https://cdn.example/old.webp"),
            "approved": recipe(3, image_url="https://x/a.webp", image_source={"status": "approved"}),
            "generated": recipe(4, image_source={"status": "generated"}),
            "queued": recipe(5, image_source={"status": "queued"}),
            "rejected": recipe(6, image_source={"status": "rejected"}),
            "failed-once": recipe(7, image_source={"status": "failed", "attempts": 1}),
            "failed-often": recipe(8, image_source={"status": "failed", "attempts": 3}),
            "curated": recipe(9),
            "fresh-generating": recipe(10, image_source={"status": "generating", "updated_at": NOW.isoformat()}),
            "stale-generating": recipe(11, image_source={"status": "generating",
                                                         "updated_at": (NOW - timedelta(hours=3)).isoformat()}),
        }
        picked = {name for name, data in states.items()
                  if lifecycle.needs_image(data, curated=curated, clock=lambda: NOW)}
        self.assertEqual(picked, {"missing", "queued", "rejected", "failed-once", "stale-generating"})

    def test_storage_path_and_seed_are_deterministic(self):
        recipe_id = recipe(1)["id"]
        self.assertEqual(lifecycle.storage_path(recipe_id, 2), f"recipe-images/{recipe_id}/hero-002.webp")
        self.assertEqual(lifecycle.seed_for(recipe_id, 2), lifecycle.seed_for(recipe_id, 2))
        self.assertNotEqual(lifecycle.seed_for(recipe_id, 1), lifecycle.seed_for(recipe_id, 2))
        with self.assertRaises(ValueError):
            lifecycle.storage_path("../etc/passwd", 1)

    def test_approval_is_explicit_and_rejection_keeps_the_served_image(self):
        store = MemoryStore([recipe(1)], FOODS)
        with tempfile.TemporaryDirectory() as directory:
            pipeline.run(pipeline.Options(), store, LocalStorage(directory), FakeProvider(), clock=lambda: NOW,
                         log=lambda *_: None)
        data = store.rows[recipe(1)["id"]]
        self.assertEqual(data["image_source"]["status"], "generated")
        self.assertIsNone(data["image_url"], "generation alone must not publish an image")
        pipeline.review(store, action="approve", recipe_ids=["recipe-1"], log=lambda *_: None)
        data = store.rows[recipe(1)["id"]]
        first_url = data["image_source"]["candidate"]["url"]
        self.assertEqual(data["image_url"], first_url)
        # A new candidate for an approved recipe does not replace the served image until approved.
        with tempfile.TemporaryDirectory() as directory:
            summary = pipeline.run(pipeline.Options(recipes=("recipe-1",), regenerate=True), store,
                                   LocalStorage(directory), FakeProvider(), clock=lambda: NOW, log=lambda *_: None)
        self.assertEqual(summary.generated, 1)
        data = store.rows[recipe(1)["id"]]
        self.assertEqual(data["image_source"]["generation"], 2)
        self.assertEqual(data["image_url"], first_url)
        pipeline.review(store, action="reject", recipe_ids=["recipe-1"], reason="cream visible", log=lambda *_: None)
        data = store.rows[recipe(1)["id"]]
        self.assertEqual(data["image_url"], first_url)
        self.assertEqual(data["image_source"]["rejected"]["reason"], "cream visible")

    def test_bulk_regeneration_is_refused(self):
        with self.assertRaises(SystemExit):
            pipeline.select([recipe(1)], pipeline.Options(regenerate=True))

    def test_approved_and_legacy_images_are_skipped_by_default(self):
        approved = recipe(1, image_url="https://x/a.webp", image_source={"status": "approved"})
        legacy = recipe(2, image_url="https://x/legacy.webp")
        store = MemoryStore([approved, legacy], FOODS)
        provider = FakeProvider()
        summary = pipeline.run(pipeline.Options(), store, LocalStorage(tempfile.mkdtemp()), provider,
                               log=lambda *_: None)
        self.assertEqual((summary.selected, provider.calls, store.writes), (0, [], []))

    def test_curated_ids_come_from_the_flutter_asset_map(self):
        self.assertIn("b6e34b78-ba48-558f-bcc8-43cf54c9131c", lifecycle.curated_recipe_ids(ROOT))


class PipelineTest(unittest.TestCase):
    def test_dry_run_prints_prompts_without_model_or_writes(self):
        store = MemoryStore([recipe(1), recipe(2)], FOODS)
        provider, lines = FakeProvider(unavailable=True), []
        summary = pipeline.run(pipeline.Options(dry_run=True), store, None, provider, log=lines.append)
        self.assertEqual(summary.selected, 2)
        self.assertEqual((provider.calls, store.writes), ([], []))
        self.assertTrue(any("Editorial food photograph" in line for line in lines))

    def test_unavailable_model_fails_before_claiming_anything(self):
        store = MemoryStore([recipe(1)], FOODS)
        with self.assertRaises(ProviderUnavailable):
            pipeline.run(pipeline.Options(), store, LocalStorage(tempfile.mkdtemp()), FakeProvider(unavailable=True),
                         log=lambda *_: None)
        self.assertEqual(store.writes, [])

    def test_failure_is_recorded_and_batch_continues_then_resumes(self):
        recipes = [recipe(n, title={"en": f"Dish {n}"}) for n in range(1, 5)]
        store = MemoryStore(recipes, FOODS)
        with tempfile.TemporaryDirectory() as directory:
            storage = LocalStorage(directory)
            summary = pipeline.run(pipeline.Options(limit=3), store, storage, FakeProvider(fail_for={'"Dish 2"'}),
                                   clock=lambda: NOW, log=lambda *_: None)
            self.assertEqual((summary.processed, summary.generated, summary.uploaded, summary.failed),
                             (3, 2, 2, 1))
            failed = store.rows[recipes[1]["id"]]["image_source"]
            self.assertEqual((failed["status"], failed["attempts"]), ("failed", 1))
            self.assertIn("out of memory", failed["last_error"])
            # Resume: finished recipes are not regenerated; the failure and the untouched one are.
            provider = FakeProvider()
            summary = pipeline.run(pipeline.Options(), store, storage, provider, clock=lambda: NOW,
                                   log=lambda *_: None)
            self.assertEqual(summary.generated, 2)
            self.assertEqual({p.split('"')[1] for p, _ in provider.calls}, {"Dish 2", "Dish 4"})
            self.assertEqual(store.rows[recipes[1]["id"]]["image_source"]["generation"], 2)

    def test_candidate_metadata_is_complete_and_file_is_uploaded(self):
        store, provider = MemoryStore([recipe(1)], FOODS), FakeProvider()
        with tempfile.TemporaryDirectory() as directory:
            pipeline.run(pipeline.Options(output_dir=Path(directory) / "keep"), store,
                         LocalStorage(Path(directory) / "bucket"), provider, clock=lambda: NOW,
                         log=lambda *_: None)
            source = store.rows[recipe(1)["id"]]["image_source"]
            candidate = source["candidate"]
            # The short CLIP summary is passed to the model and recorded next to the full prompt.
            self.assertEqual(provider.short_prompts, [candidate["clip_prompt"]])
            self.assertLessEqual(len(candidate["clip_prompt"]), 300)
            for key in ("path", "url", "prompt", "prompt_version", "seed", "provider", "model", "generated_at",
                        "source_width", "source_height", "width", "height", "bytes", "sha256", "pipeline_version"):
                self.assertIn(key, candidate)
            self.assertEqual((candidate["width"], candidate["height"]), ASSET_SIZE)
            self.assertEqual((source["kind"], source["owner"], source["schema"]), ("ai-generated", "EatMe", 1))
            uploaded = Path(directory) / "bucket" / candidate["path"]
            self.assertEqual(len(uploaded.read_bytes()), candidate["bytes"])
            self.assertTrue((Path(directory) / "keep" / candidate["path"]).with_suffix(".source.png").exists())
            json.dumps(source)  # stays JSON-serialisable for recipes.data

    def test_invalid_output_is_rejected_before_upload(self):
        store = MemoryStore([recipe(1)], FOODS)
        with tempfile.TemporaryDirectory() as directory:
            summary = pipeline.run(pipeline.Options(), store, LocalStorage(directory), FakeProvider(blank=True),
                                   log=lambda *_: None)
            self.assertEqual((summary.failed, summary.uploaded), (1, 0))
            self.assertEqual(list(Path(directory).rglob("*.webp")), [])
        self.assertIn("InvalidImage", store.rows[recipe(1)["id"]]["image_source"]["last_error"])

    def test_representative_sample_spreads_dish_types(self):
        store = CatalogFileStore(ROOT)
        sample = pipeline.representative_sample(store.recipes(), 10)
        self.assertEqual(len(sample), 10)
        self.assertGreaterEqual(len({dish_type(r)[0] for r in sample}), 8)


class OptimizeTest(unittest.TestCase):
    def test_optimize_crops_to_card_ratio_and_stays_small(self):
        source = FakeProvider().generate("x", 1, 1280, 800)
        asset = validate(optimize(source))
        self.assertEqual((asset.width, asset.height, asset.source_width), (1200, 750, 1280))
        with Image.open(io.BytesIO(asset.data)) as image:
            self.assertEqual((image.format, image.size), ("WEBP", (1200, 750)))
        square = optimize(FakeProvider().generate("x", 2, 1600, 1600))
        self.assertEqual((square.width, square.height), (1200, 750))

    def test_validation_rejects_bad_files(self):
        asset = optimize(FakeProvider().generate("x", 1, 1280, 800))
        for data in (b"", b"not an image" * 2000):
            asset.data = data
            with self.assertRaises(InvalidImage):
                validate(asset)
        with self.assertRaises(InvalidImage):
            optimize(Image.new("RGB", (640, 400)))


class ApiPayloadTest(unittest.TestCase):
    def test_clients_do_not_receive_generation_metadata(self):
        from eatme.service import Service
        from eatme.storage import Database, encode

        with tempfile.TemporaryDirectory() as directory:
            db = Database(directory + "/eatme.db")
            db.migrate_local()
            service = Service(db)
            data = recipe(1, image_url="https://cdn.example/hero-001.webp", image_source={
                "kind": "ai-generated", "owner": "EatMe", "status": "approved", "schema": 1,
                "candidate": {"prompt": "long prompt", "seed": 7}, "approved": {"prompt": "long prompt"}})
            with service.db.transaction() as tx:
                tx.execute("INSERT INTO recipes(id,data) VALUES (?,?)", (data["id"], encode(data)))
            with service.db.transaction() as tx:
                served = next(r for r in service._catalog(tx)[1] if r["id"] == data["id"])
                stored = json.loads(tx.one("SELECT data FROM recipes WHERE id=?", (data["id"],))["data"])
        self.assertEqual(served["image_url"], "https://cdn.example/hero-001.webp")
        self.assertEqual(served["image_source"], {"kind": "ai-generated", "owner": "EatMe", "status": "approved"})
        self.assertNotIn("image_prompt", served)
        self.assertIn("candidate", stored["image_source"], "the database keeps the full audit record")


class SupabaseStorageTest(unittest.TestCase):
    def test_upload_uses_immutable_path_and_service_headers(self):
        calls = []

        def call(url, data=None, headers=None, method=None):
            calls.append((method or "GET", url, headers))
            return 200, b"{}"

        storage = SupabaseStorage("https://demo.supabase.co", "service-key", call=call)
        storage.ensure_bucket()
        url = storage.upload("recipe-images/x/hero-001.webp", b"data")
        self.assertEqual(url, "https://demo.supabase.co/storage/v1/object/public/eatme-catalog-media/"
                              "recipe-images/x/hero-001.webp")
        method, target, headers = calls[-1]
        self.assertEqual((method, headers["Content-Type"]), ("POST", "image/webp"))
        self.assertIn("max-age=", headers["Cache-Control"])
        with self.assertRaises(Exception):
            SupabaseStorage("http://insecure", "k")


if __name__ == "__main__":
    unittest.main()
