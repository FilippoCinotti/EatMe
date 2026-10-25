# Smart Experience editorial interface

The implementation extends the merged Smart Experience services. No database
migration, catalog image replacement, paid service or ranking engine is added.

## Interactions

- ChefTable restores encrypted, account-scoped recommendations for the current
  mode and meal slot after profile bootstrap, then refreshes automatically. A
  failed refresh keeps the previous compatible-context view. Profile settings or
  household changes invalidate stored snapshots. Requests with identical refresh
  scope share one future; stale account/mode responses cannot replace newer ones.
- Three contextual photographs show one ranking reason each and persistent
  favorites. Available content width permits the iPad horizontal arrangement.
- Long-press an inventory photograph to select; use the persistent compact action
  bar for select all, move, consume, remove or cancel. Tooltips and semantic labels
  identify icon actions. The filter menu retains an accessible selection entry.
- The planner uses compact meal rows on narrow windows and a seven-day table on
  wide windows. Large accessibility text falls back to rows. Calendar editing uses
  the existing versioned lock, suggestion and rescheduling commands.
- Recipe alternatives use the existing recommendation results; opening a recipe
  retains its existing compatibility and consumption validation workflow.
- Cooking uses recipe photography and a step sidebar on wide windows. Timers
  remain independent and persistent; the toolbar exposes timer controls in a sheet.
- Cooking confirmation uses compact consumption rows and the existing single
  idempotent confirmation for inventory and leftovers.
- Shopping uses grouped rows with thumbnails, quantities, estimates, checkboxes
  and the existing edit, purchase, partial purchase and remove commands.

Typography never increases intentionally. Native accessibility scaling remains
enabled; responsive decisions use available width. Photography comes from the
existing catalog and is never synthesized from production data in tests.

## Verification

`smart_experience_layout_test.dart` exercises all six screens at phone, tablet
portrait and tablet landscape sizes in both themes, writing real Flutter renders
to the CI interface-review artifact. The snapshots use test-only fixtures and are
not production data. Network resilience tests cover restoration during refresh
failure; existing API, PostgreSQL authorization and transaction tests remain in CI.

Device-only VoiceOver/TalkBack, physical iPad Stage Manager and production network
behavior still require release-device smoke testing; fixture renders do not
constitute production validation.
