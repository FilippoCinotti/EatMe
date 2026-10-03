# Rilascio del catalogo ricette v5 (3.604 ricette + foto AI) e dispensa

Istruzioni operative, pensate per essere seguite da un assistente (es. ChatGPT) o da una persona
con accesso al repository GitHub `FilippoCinotti/EatMe` e al progetto Supabase `ngqetldudwzemdhjprmv`.
Seguile nell'ordine; ogni passo dice come verificare che sia andato a buon fine.

## Cosa contiene la PR

| File | Scopo |
|---|---|
| `generated/verified_recipes_catalog.json` | 3.604 ricette verificate (IT/EN), più l'elenco `foods` dei nuovi alimenti di catalogo, ingredienti mappati sul catalogo alimenti, `meal_types`, `diet_tags`, `image_prompt` |
| `docs/catalog/verified-recipes-v1.json` | Manifest delle fonti (catalog_version 4, 1.034 voci) |
| `scripts/load_verified_recipes.py` | Upsert idempotente delle ricette nella tabella `recipes` (dry run di default) |
| `scripts/generate_recipe_images.py` | Genera le foto con un modello open locale (FLUX.1-schnell), le carica su Supabase Storage; `image_url` solo dopo approvazione (vedi `docs/catalog/recipe-images.md`) |
| `.github/workflows/catalog-recipes-load.yml` | Workflow manuale per il caricamento ricette |
| `.github/workflows/catalog-recipe-images.yml` | Workflow manuale per le foto |
| `services/api/tests/test_verified_catalog.py` | Validazione del catalogo e del loader |

Nessuna migrazione di schema: le ricette sono righe `recipes(id, data)` già esistenti come struttura.

## 1. Merge della PR

1. Verifica che la CI della PR sia verde (job `api`, `postgres-rls`, `mobile`).
2. Fai il merge su `main` (squash o merge commit, come da abitudine del repo).
3. I due workflow `workflow_dispatch` compaiono in *Actions* solo dopo il merge su `main`.

## 2. Secret e variabili (GitHub → Settings → Environments → `production`)

Entrambi i workflow girano nell'environment `production`. Crea l'environment se non esiste e aggiungi:

| Nome | Tipo | Valore |
|---|---|---|
| `CATALOG_DATABASE_URL` | secret | Connection string PostgreSQL di Supabase con permesso di scrittura su `recipes` (Supabase → Project Settings → Database → Connection string, modalità *Session pooler*, utente `postgres`) |
| `SUPABASE_SERVICE_ROLE_KEY` | secret | Supabase → Project Settings → API → `service_role` |
| `HF_TOKEN` | secret | Solo per la generazione foto: token Hugging Face (gratuito) di un account che ha accettato i termini di FLUX.1-schnell |
| `SUPABASE_URL` | variable | `https://ngqetldudwzemdhjprmv.supabase.co` (già usata dal workflow TestFlight: se esiste a livello repository va bene) |

Non incollare mai questi valori in chat, issue o commit.

## 3. Migrazione database (dispensa)

Prima del deploy dell'API applica la migrazione `supabase/migrations/202609270007_household_pantry.sql`
(tabella `household_pantry` con RLS) con la procedura abituale: `python scripts/migrate.py` e
`MIGRATION_DATABASE_URL` da un ambiente operatore fidato (vedi `docs/releases/deployment-runbook.md`).
Lo script applica solo le migrazioni mancanti.

## 3b. Caricamento ricette

1. *Actions* → **Load verified recipe catalog** → *Run workflow* con `apply = false` (dry run).
2. Nel log verifica la riga
   `foods: F to insert, K matched to existing foods by slug` e
   `catalog v5: 3604 recipes; N loadable (… new, … updates); M skipped for unknown foods`.
   - Gli alimenti nuovi del catalogo vengono inseriti solo se non esiste già un alimento con lo stesso `slug`.
   - Atteso: `M = 0`. Se `M > 0` il log elenca le prime ricette saltate e gli `food_id` mancanti:
     significa che la tabella `foods` di produzione non contiene quegli alimenti del catalogo
     (`scripts/catalog_image_targets.json`). Si può procedere comunque: le ricette saltate non vengono scritte.
3. Rilancia con `apply = true`. Atteso: `Inserted F foods; upserted N recipes.`
4. Il comando è idempotente: rilanciarlo aggiorna le stesse righe senza duplicati e **conserva** le foto già collegate.

## 4. Generazione foto

Le foto sono immagini originali EatMe generate con un modello open eseguito in locale (FLUX.1-schnell):
nessuna API a pagamento, nessuna foto delle fonti copiata. Procedura completa, requisiti GPU e comandi in
[`recipe-images.md`](recipe-images.md). In sintesi:

1. *Actions* → **Generate recipe catalog images** → `mode = dry-run`: stato e prompt dalle ricette reali.
2. Su una macchina con GPU (o runner self-hosted con etichetta `gpu`, `mode = generate`):
   prima `--sample 10`, revisione con `--review-sheet`, `--approve` delle buone, verifica nell'app.
3. Poi il catalogo completo con `--missing` (riprendibile: rilanciare lo stesso comando).
   Le immagini compaiono nell'app solo dopo `--approve`.

## 5. Verifica finale in produzione

- API: con un utente reale, `GET /api/v1/recipes` deve restituire le nuove ricette (campo `source_url`,
  `meal_types`, `image_url` valorizzato).
- App: la libreria ricette e i suggerimenti mostrano le nuove ricette con foto e timer sui passaggi.
- Nessun deploy dell'API o nuova build mobile è necessario: i dati sono letti dal database a runtime.

## Rollback

- Foto: `--reject <slug>` ritira un'immagine dall'app; per tutte, `image_url = null` sulle ricette con `image_source.kind = ai-generated` (dettagli in `recipe-images.md`).
- Ricette: le righe nuove hanno `catalog_version = 5` nel JSON `data`; si possono rendere invisibili
  impostando `recommendation_eligible = false` (vengono escluse da libreria e suggerimenti) oppure
  eliminarle se non hanno preferiti/feedback collegati.
