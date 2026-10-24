# Recorded impact periods

The existing Insights screen can request 7, 30 or 90 calendar days. Recorded meals and distinct recipes, inventory quantities and source-backed impact estimates are filtered to that same interval. A small daily meals chart uses the theme accent, semantic date/count descriptions and tooltips. Counted days are UTC; the response explicitly identifies the timeline timezone. Empty days have a real count of zero, while missing economic/environmental estimates remain null and display unavailable.

The existing documented impact methodology, source factors and coverage limitations are unchanged. No invented savings or unit conversion is added. The response identifies the existing scope distinction: cooking sessions are personal; inventory events belong to the authorized household. Legacy callers without `days` retain the old bounded-history response.

Two regression tests cover inclusive/exclusive date boundaries, 7/30/90 windows, daily counts, external-preparation exclusions, missing impact factors and invalid periods. Existing sustainability tests remain required. Flutter analysis, chart layout and screenshots await CI. Richer supported observations and timezone-local day bucketing remain outstanding.

No schema migration, new chart dependency, production change, merge or deployment.
