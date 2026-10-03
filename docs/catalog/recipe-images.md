# Recipe hero images (local open model)

EatMe generates an original photograph of the **finished dish** for every catalog recipe that does not
already have an approved image. The model runs on a machine we control, so there is no pay-per-image
API and no image fallback that costs money. No photograph from a third-party website is scraped, copied
or used as a reference. Recipe attribution (`source_*` fields) is not modified by this pipeline.

## Workflow

```
new recipe in the catalog
  → prompt built from the recipe data
  → FLUX.1-schnell generates a 1280×800 source image locally (4 steps, fixed seed)
  → validation + 1200×750 WebP (≤ 450 KB)
  → upload to Supabase Storage  eatme-catalog-media/recipe-images/{recipe_id}/hero-{NNN}.webp
  → image_source.status = generated   (candidate, NOT visible in the app yet)
  → review (review sheet) → --approve   → image_url set → visible in the app
                          → --reject    → the next batch generates a new candidate
```

## Architecture

| Piece | File | Role |
|---|---|---|
| CLI | `scripts/generate_recipe_images.py` | batch, single recipe, review, status, preview, dry run |
| Prompt | `scripts/recipe_images/prompt.py` | recipe → prompt (`eatme-hero-v1`) |
| Lifecycle | `scripts/recipe_images/lifecycle.py` | statuses, eligibility, deterministic path and seed |
| Pipeline | `scripts/recipe_images/pipeline.py` | select → claim → generate → validate → upload → record |
| Optimisation | `scripts/recipe_images/optimize.py` | crop/resize, WebP, file checks |
| Providers | `scripts/recipe_images/providers.py` | `flux-schnell` (Diffusers); swappable |
| Data | `scripts/recipe_images/stores.py` | Postgres (production), catalog file (dry run) |
| Storage | `scripts/recipe_images/storage.py` | Supabase Storage (production), local folder (preview) |
| Workflow | `.github/workflows/catalog-recipe-images.yml` | dry run on GitHub; generation on a self-hosted GPU runner |

### Data: no migration

Recipes are stored as a JSON document (`recipes.data`). The pipeline changes only two keys of that
document, one recipe at a time under a row lock (`SELECT … FOR UPDATE`):

- `image_url`: the URL the app renders. It is set **only on approval**.
- `image_source`: the existing metadata object, extended (schema 1):

```json
{
  "kind": "ai-generated", "owner": "EatMe", "schema": 1,
  "status": "generated",
  "generation": 2, "attempts": 0, "last_error": null, "updated_at": "…",
  "candidate": {
    "generation": 2, "path": "recipe-images/<id>/hero-002.webp", "url": "https://…",
    "prompt": "…", "clip_prompt": "…", "prompt_version": "eatme-hero-v1", "seed": 123456789,
    "provider": "flux-schnell", "model": "black-forest-labs/FLUX.1-schnell", "steps": 4,
    "guidance_scale": 0.0, "device": "cuda", "diffusers": "…", "torch": "…",
    "source_width": 1280, "source_height": 800, "width": 1200, "height": 750,
    "bytes": 181234, "quality": 82, "sha256": "…",
    "pipeline_version": "recipe-images-1", "generated_at": "…"
  },
  "approved": { "…the approved candidate…", "approved_at": "…" },
  "rejected": { "…", "rejected_at": "…", "reason": "…" }
}
```

The API sends clients only `image_source.kind/owner/status` and drops `image_prompt`
(`client_recipe` in `services/api/eatme/service.py`). This keeps `/recipes` light because it returns
the whole catalog. The released app reads only `image_url` (and `hero_image_url`/`thumbnail_url`), so the
change is backward compatible. The catalog loader already keeps `image_url` and `image_source` from the
database (`KEEP_FROM_DATABASE`), so reloading the catalog never removes images.

### Statuses

| Status | Meaning | Picked by `--missing` |
|---|---|---|
| `missing` | no image (no `image_source`, no `image_url`) | yes |
| `queued` | queued for regeneration (`--queue`) | yes |
| `generating` | claimed by a running batch | only if stale (> 2 h, crashed run) |
| `generated` | candidate uploaded, **awaiting review**; not visible in the app | no |
| `approved` | `image_url` points to the approved candidate | no |
| `rejected` | reviewer rejected it; `image_url` keeps any previously approved image | yes |
| `failed` | generation, validation or upload failed; `attempts` counts consecutive failures | up to 3 attempts (`--retry-failed` for more) |
| `legacy` | `image_url` set before this pipeline, no status | no (only `--recipe … --regenerate`) |
| `curated` | recipe with a bundled image in the app (`FoodImage.recipeAssets`) | never |

An approved image is never overwritten. `--regenerate` works only with explicit `--recipe` values. It creates a
new candidate with a new generation number, so the approved file and its URL stay live until the new
candidate is itself approved.

### Paths, sizes and naming

- **Path:** `recipe-images/{recipe_id}/hero-{generation:03d}.webp` in the public bucket
  `eatme-catalog-media` (`image/webp` only, 2 MB limit; created if missing with the settings the catalog
  already uses).
  - The path is deterministic: the recipe id plus the generation number stored in the metadata.
  - A new generation gets a new path, so files are immutable. They are served with a one-year cache
    (`max-age=31536000`) and a regeneration can never leave phones showing a stale cached image.
- **Seed:** `sha256(recipe_id:generation)`, so any image can be reproduced from its metadata.
- **Sizes:** the source is 1280×800 (1.6:1, which FLUX requires to be a multiple of 16). The asset is 1200×750 WebP, quality 82, reduced
  step by step until it is ≤ 450 KB.
  - The app shows images with `BoxFit.cover` in 1.6:1 heroes (full width, up to 320 px tall) and in 72–82 px
    square thumbnails.
  - The prompt keeps the dish centred with space around it, so the square crop still shows the dish.

### Quality checks before upload

- The file is not empty.
- It is between 12 KB and 450 KB.
- It opens with Pillow (`verify`).
- Its format is `WEBP`.
- It is exactly 1200×750.
- It is not a flat or blank frame (mean channel standard deviation ≥ 12).

A source image smaller than the asset is rejected rather than upscaled. A failure marks only that recipe
`failed`, and the batch continues.

Generation never approves an image. A person reviews candidates with the review sheet.

## Prompts

`build_prompt` uses the recipe's real data, in this order of importance:

1. **Title, cuisine and dish type.** The type comes from the English title, e.g. *soup → served in a wide bowl*,
   *cake → one slice with the rest behind*, *pasta → shallow bowl*.
2. **The curated visual description (`image_prompt`).** It was written from the full source recipe, for example
   "mezzi rigatoni coated in glossy golden egg and pecorino sauce with crisp strips of guanciale". Its camera,
   light and scenery clauses are removed so the shared art direction decides them.
3. **The main canonical ingredients, ranked by weight.** Invisible ones such as salt, oil, water and leavening
   are left out.
4. **The cooking method found in the steps** (oven-baked, grilled, slow-cooked, uncooked…) and the final
   serving step.
5. **An explicit list of common invented garnishes the recipe does not use.** For carbonara:
   *"Do not add parsley, basil, coriander, mint, cream, tomato or any ingredient not in the recipe"*.
   Words are matched whole, so "creamy sauce" in a step does not count as cream.
6. **The same art direction and exclusions for every recipe**: soft natural side window light, 35° angle,
   subtle shallow depth of field, minimal warm neutral stone surface, dish centred, finished plated dish only,
   no raw-ingredient spread, collage, cooking scene, text, labels, packaging, logos, watermark, people or hands.

FLUX.1-schnell has two text encoders:

- **T5** reads at most 256 tokens and gets the full prompt (`prompt_2`).
  - **Budget:** prompts are kept under 900 characters. Optional parts are dropped first when a prompt is too
    long.
  - **Measured:** all 3,604 catalog prompts measured with the T5 tokenizer are 139–238 tokens (median 199).
- **CLIP** reads 77 tokens and gets a short summary (`clip_prompt`): title, dish type, serving and the core
  style. Measured: 31–51 tokens.

`test_every_catalog_prompt_fits_the_text_encoder_budget` enforces the character budget. Both prompts are
stored with the image.

Change the prompt only together with `PROMPT_VERSION`. The version is stored with every image.

## Hardware and model

- **Model:** [FLUX.1-schnell](https://huggingface.co/black-forest-labs/FLUX.1-schnell) (12B parameters,
  Apache-2.0, commercial use allowed).
  - The Hugging Face repository is *gated*: sign in with a free account, accept the terms on the model page,
    then create a read token and set `HF_TOKEN` on the GPU machine.
  - The weights (~34 GB) are downloaded once to `HF_HOME`.
- **GPU requirements:**

  | GPU | Setting | Notes |
  |---|---|---|
  | NVIDIA 24 GB (RTX 3090/4090, L4, A10G) | `--offload model` (default) | recommended; roughly a few seconds per image, so the full catalog takes a few hours |
  | NVIDIA ≥ 40 GB (A100, H100) | `--offload none` | fastest |
  | NVIDIA 12–16 GB | `--offload sequential` | works, much slower |
  | Apple Silicon ≥ 32 GB unified memory | automatic `mps` | slow, fine for small batches |

- **Other requirements:** 64 GB system RAM is recommended with offload, plus 40 GB of free disk.
- **No GPU:** the command stops with exit code 3 before touching the database and prints how to proceed. It never
  falls back to a paid API. `--allow-cpu` exists only for smoke tests with a tiny model.

### Local setup (GPU machine)

```bash
git clone https://github.com/FilippoCinotti/EatMe && cd EatMe
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r scripts/recipe_images/requirements-gpu.txt   # install the CUDA build of torch first if needed
export HF_TOKEN=…                    # entered by the operator, never committed
export CATALOG_DATABASE_URL=…        # same secret as the catalog loader
export SUPABASE_URL=https://ngqetldudwzemdhjprmv.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=…   # used only for the Storage upload
```

Optional variables:
- `CATALOG_MEDIA_BUCKET` (default `eatme-catalog-media`)
- `RECIPE_IMAGE_MODEL` (model id or local path)
- `RECIPE_IMAGE_MODEL_REVISION` (pin a model revision)
- `RECIPE_IMAGE_DEVICE`
- `HF_HOME` (weights cache)

Secrets are read only from the environment. They are never printed and never written to files.

## Commands

```bash
# Dry run: selection and prompts, no model, no writes (works without a GPU and without the database,
# using the committed catalog file; with CATALOG_DATABASE_URL it reads the live recipes).
python scripts/generate_recipe_images.py --dry-run --limit 20
python scripts/generate_recipe_images.py --dry-run --recipe authentic-carbonara

# Status counts
python scripts/generate_recipe_images.py --status

# Local preview only: files in a folder + review.html, no upload, no database writes
python scripts/generate_recipe_images.py --preview build/recipe-images --sample 10

# First validation: 10 representative recipes (different dish types, cuisines, meal slots)
python scripts/generate_recipe_images.py --missing --sample 10 --output-dir build/recipe-images

# Single recipe
python scripts/generate_recipe_images.py --recipe authentic-carbonara

# Batch (resumable; rerun the same command after an interruption)
python scripts/generate_recipe_images.py --missing --limit 500

# Review
python scripts/generate_recipe_images.py --review-sheet review.html
python scripts/generate_recipe_images.py --approve authentic-carbonara risogalo --reviewer filippo
python scripts/generate_recipe_images.py --reject asparagi-con-feta --reason "tomato visible"

# Regenerate an approved image (explicit recipe only; the approved image stays live until the new one is approved)
python scripts/generate_recipe_images.py --recipe authentic-carbonara --regenerate
python scripts/generate_recipe_images.py --queue authentic-carbonara      # or let the next batch do it
```

Exit codes: `0` success, `1` at least one recipe failed, `3` model unavailable (nothing was written).

### GitHub Actions

*Actions → Generate recipe catalog images* has two modes:

- **`mode = dry-run`** runs on GitHub's Ubuntu runners. It reads the live recipes with `CATALOG_DATABASE_URL`
  and prints the status counts and the prompts.
- **`mode = generate`** runs on a **self-hosted runner** with the labels `self-hosted, gpu`, in the `production`
  environment.
  - Secrets: `CATALOG_DATABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `HF_TOKEN`. Variable: `SUPABASE_URL`.
  - GitHub-hosted runners have no GPU. To add one, register the GPU machine as a runner under
    *Settings → Actions → Runners → New self-hosted runner* and give it the `gpu` label.

The `OPENAI_API_KEY` secret is no longer used by this workflow.

## Failure recovery

- **Interrupted batch** (crash, reboot, Ctrl-C): rerun the same command.
  - Completed recipes are `generated` and are skipped.
  - A recipe left `generating` is picked up again after 2 hours.
  - To retry it immediately, use `--recipe <slug>`.
- **Failed recipes:** `--status` shows the count, and `last_error` in `image_source` says why.
  - They are retried automatically up to 3 times.
  - `--retry-failed` retries them regardless.
  - `--recipe <slug>` always retries that recipe.
- **Bad image in the app:** use `--reject <slug>`, which withdraws an approved image and clears `image_url`.
  The next batch then generates a new one.
- **Roll back one recipe to its previous approved image:** set `image_url` back to the URL in
  `image_source.rejected` or `image_source.approved`. Older files stay in Storage because paths are immutable.
- **Roll back everything:** set `image_url` to null for recipes whose `image_source.kind` is `ai-generated`,
  and optionally empty `recipe-images/` in the bucket. The app falls back to its neutral placeholder.
  There is no schema to revert.

## Replacing the model

1. Add a provider class to `scripts/recipe_images/providers.py`. It needs `name`, `check()`,
   `generate(prompt, seed, width, height) -> PIL.Image` and `metadata()`, and it must raise
   `ProviderUnavailable` when it cannot run.
2. Register it in `PROVIDERS` and run with `--provider <name>`.
3. For another FLUX-compatible checkpoint (for example a fine-tune in the Diffusers format), `--model <id or path>`
   is enough.
4. Bump `PROMPT_VERSION` if the prompt changes.
5. Use `--queue` or `--regenerate` for the recipes you want re-shot. Other images stay as they are.

The database layout and the Storage layout do not depend on the model.
