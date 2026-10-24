# Multiple cooking timers

Each step can retain an independent named timer. Start a timer on a step, then navigate to another step and start another. All timers appear in the existing timer panel; each can pause, resume, stop, or navigate back to its step. Timers use persisted UTC deadlines, not tick counts, so suspension does not lose elapsed time. Persistence is scoped to the signed-in account and recipe, using existing secure storage, with serialized writes and visible restore/save failures.

Timer notifications require an explicit Enable timer alerts action. Native permission denial or scheduling failure leaves the timer visible with an error. Scheduling replaces the same notification ID. Stopping or pausing cancels that timer's notification. Routine kitchen-reminder refresh no longer cancels cooking timers; account sign-out still clears all pending notifications. Android uses the existing inexact-while-idle notification mode; delivery time is controlled by the OS and cannot be guaranteed.

Two automated tests cover suspension, expiration, pause/resume, independent timers and account/recipe-scoped restoration. Flutter analysis and device validation await CI. Native voice commands, a dedicated iPad two-pane cooking layout and in-cooking substitutions remain outstanding; this is not a complete Cooking Now 2.0 delivery.

No dependency added, cloud provider, migration, merge or deployment.
