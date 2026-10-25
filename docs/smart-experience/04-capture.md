# Smart Capture provenance and evaluation

Existing automatic photo/receipt classification, original-photo review, uncertain-item warnings, canonical-food corrections, quantities/units and a single final inventory approval are preserved. The configured provider schema can now extract an explicitly printed use-by or best-before date with short label evidence. Dates without evidence or type/date inconsistencies are rejected; no provider-generated shelf-life estimate is accepted. Older five-field provider fixtures remain compatible. The review shows captured label text; missing dates still use the existing clearly estimated/manual flow. Confirmed inventory metadata retains capture job ID, quantity confirmation and date provenance.

`eatme.capture_evaluation.evaluate_captures` evaluates offline reference/prediction pairs: classification accuracy, canonical ingredient precision/recall, unit error, quantity relative error, observed corrections and observed completion. Denominators are returned; unavailable measurements remain null. Repeated items cannot inflate recall. It calls no provider and creates no recurring cost.

Four new tests cover metric denominators/errors and label-date evidence/approval isolation; existing capture/provider-error tests remain required. These synthetic fixtures validate the evaluation code and boundary behavior; they do not measure real-world recognition accuracy. A consented, annotated photo/barcode/receipt benchmark and production accuracy assessment are still needed. Automatic barcode detection in the single photo flow is not added in this PR.

No new AI service, production configuration, schema migration, merge or deployment.
