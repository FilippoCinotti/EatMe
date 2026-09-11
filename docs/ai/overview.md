# Assisted processing

The application implements durable photo, receipt and recipe jobs with queued, processing, completed, failed and cancelled states. Workers use leases and bounded retries. Late results cannot overwrite cancelled or newer job versions. Every user-visible result remains a candidate until reviewed.

Images are size/type/dimension checked, resized, stripped of metadata and encrypted in private storage. Food/receipt uploads expire after 24 hours and require the worker's retention task. Provider requests contain selected content and canonical catalog identifiers, not the health profile. Model configuration and secret keys stay on the server.

A versioned prompt treats text and images as untrusted data. Strict structured output is checked again by the service. Unknown detections require mapping; no stock is created by a recognition result alone. Recipe candidates pass normal canonical/diet validation when saved. AI cannot publish scientific evidence, invent a medical rule or assign a universal health score.

Development fixture mode is explicit, visibly labelled and blocked outside development. Evaluate recognition quality separately from fixture-based workflow tests, using licensed/consented evaluation images and documented correction rates.
