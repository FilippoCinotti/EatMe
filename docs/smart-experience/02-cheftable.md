# Contextual ChefTable cards

The existing recommendations response now includes `contextual` cards for For you, Use soon and Quick. Selection consumes already filtered and ranked candidates, without another compatibility algorithm or extra mobile API calls. A bounded maximum matching keeps the three cards distinct when the eligible catalog permits it. Quick retains the existing 15-minute threshold. Categories without eligible candidates are omitted instead of relabeling a generic dish. Each card has one or two evidence-based reasons and no confidence percentages.

Cards use semantic theme surfaces and compact photos. Available width controls a one-column phone layout and three-column wide layout. Search, modes, filters, favorites and existing recipe actions remain available. Recipes already displayed in contextual cards are removed from the secondary recommendations list.

Explicit feedback was already consent-gated. Recorded cooking history now contributes a small capped ranking bonus only when learning consent is enabled. Merely ignoring a recipe is never treated as negative feedback. Existing explicit cuisine, skill, budget and maximum-time preferences are preserved.

Three new selector tests cover scarce candidates, limited catalogs and evidence-based explanations; existing API ranking tests remain required. Flutter/widget/device screenshots and native builds await CI. Participant selection integration and richer habitual-time learning remain outstanding; this PR does not claim the entire ChefTable 2.0 specification is complete.

No database migration, paid provider, production configuration change or deployment.
