# Contributing

Use short feature branches and a focused pull request. Explain the user problem, resulting behavior, validation and remaining limitations. Keep documentation, comments, commit messages and review text in English. Localize mobile UI strings in both resource files.

Run API tests, static checks and relevant platform checks before requesting review. Changes to quantities, permissions, consent or clinical validation need behavioral tests. Do not add tests that only mirror implementation details. Never modify an applied database migration; add a new version. Regenerate and review lockfiles when dependencies change.

Private recipe imports must remain private. Unknown ingredients and unsupported rules fail closed. Published clinical profiles may be selectable without an evidence-reference gate, but they must keep explicit consent, non-medical-advice language and all hard-safety behavior. Evidence and review metadata must never be presented as a guarantee of clinical validity. Fixture data must stay visibly distinguishable. Never commit credentials, personal data, generated runtime configuration or signing material.
