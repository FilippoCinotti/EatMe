# Rilascio del catalogo ricette v4 (1.023 ricette + foto AI)

Istruzioni operative, pensate per essere seguite da un assistente (es. ChatGPT) o da una persona
con accesso al repository GitHub `FilippoCinotti/EatMe` e al progetto Supabase `ngqetldudwzemdhjprmv`.
Seguile nell'ordine; ogni passo dice come verificare che sia andato a buon fine.

## Cosa contiene la PR

| File | Scopo |
|---|---|
| `generated/verified_recipes_catalog.json` | 1.023 ricette verificate (IT/EN), ingredienti mappati sul catalogo alimenti, `meal_types`, `diet_tags`, `image_prompt` |
| `docs/catalog/verified-recipes-v1.json` | Manifest delle fonti (catalog_version 4, 1.034 voci) |
| `scripts/load_verified_recipes.py` | Upsert idempotente delle ricette nella tabella `recipes` (dry run di default) |
| `scripts/generate_recipe_images.py` | Genera le foto con OpenAI, le carica su Supabase Storage e imposta `image_url` |
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
| `OPENAI_API_KEY` | secret | Chiave OpenAI con accesso alle Images API (gpt-image) |
| `SUPABASE_URL` | variable | `https://ngqetldudwzemdhjprmv.supabase.co` (già usata dal workflow TestFlight: se esiste a livello repository va bene) |

Non incollare mai questi valori in chat, issue o commit.

## 3. Caricamento ricette

1. *Actions* → **Load verified recipe catalog** → *Run workflow* con `apply = false` (dry run).
2. Nel log verifica la riga
   `catalog v4: 1023 recipes; N loadable (… new, … updates); M skipped for unknown foods`.
   - Atteso: `M = 0`. Se `M > 0` il log elenca le prime ricette saltate e gli `food_id` mancanti:
     significa che la tabella `foods` di produzione non contiene quegli alimenti del catalogo
     (`scripts/catalog_image_targets.json`). Si può procedere comunque: le ricette saltate non vengono scritte.
3. Rilancia con `apply = true`. Atteso: `Upserted N recipes.`
4. Il comando è idempotente: rilanciarlo aggiorna le stesse righe senza duplicati e **conserva** le foto già collegate.

## 4. Generazione foto

Le foto sono illustrazioni AI di proprietà EatMe (nessuna foto delle fonti viene ripubblicata).

1. *Actions* → **Generate recipe catalog images** → *Run workflow* con `dry_run = true`.
   Atteso nel log: `1023 images to generate; 0 catalog recipes not loaded yet`.
2. Prova su pochi elementi: `dry_run = false`, `limit = 20`, `quality = medium`.
   - Controlla alcune immagini: Supabase → Storage → bucket `eatme-catalog-media` → cartella `recipes/`
     (il bucket viene creato pubblico automaticamente, solo `image/webp`, max 2 MB).
   - Controlla nell'app che le ricette mostrino la nuova foto.
3. Completa: `limit = 0` (tutte le mancanti). Il job dura al massimo ~6 ore; se si interrompe o
   segnala `FAILED`, rilancialo: salta le ricette che hanno già `image_url`.
4. Costo indicativo OpenAI per 1.023 immagini 1024×1024: circa 11 $ (`low`), 40–45 $ (`medium`), 170 $ (`high`).
   Verifica i prezzi correnti su platform.openai.com prima di lanciare.

## 5. Verifica finale in produzione

- API: con un utente reale, `GET /api/v1/recipes` deve restituire le nuove ricette (campo `source_url`,
  `meal_types`, `image_url` valorizzato).
- App: la libreria ricette e i suggerimenti mostrano le nuove ricette con foto e timer sui passaggi.
- Nessun deploy dell'API o nuova build mobile è necessario: i dati sono letti dal database a runtime.

## Rollback

- Foto: rimuovere `image_url`/`image_source` dalle righe interessate e svuotare `recipes/` nel bucket.
- Ricette: le righe nuove hanno `catalog_version = 4` nel JSON `data`; si possono rendere invisibili
  impostando `recommendation_eligible = false` (vengono escluse da libreria e suggerimenti) oppure
  eliminarle se non hanno preferiti/feedback collegati.
