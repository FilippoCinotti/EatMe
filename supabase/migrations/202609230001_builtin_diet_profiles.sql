BEGIN;

-- Built-in self-declared eating styles required by the mobile profile editor.
-- These are product filtering/ranking profiles, not diagnoses or treatment plans.
-- Clinical profiles (including celiac and RAD) remain governed content and are
-- intentionally NOT seeded here; they must be independently reviewed/published.
WITH builtin(slug, id, data) AS (
  VALUES
    ('balanced','88e5d9e2-7265-57cf-aa44-df19ef20da3f','{"id":"88e5d9e2-7265-57cf-aa44-df19ef20da3f","slug":"balanced","name":{"it":"Equilibrata","en":"Balanced"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"A neutral profile with no additional food exclusions.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('omnivore','49991e58-ea02-555d-bcc6-a029f94bd3c3','{"id":"49991e58-ea02-555d-bcc6-a029f94bd3c3","slug":"omnivore","name":{"it":"Onnivora","en":"Omnivore"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"A neutral eating style with no additional food exclusions.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('mediterranean','5a98bb93-6a4f-574f-a7dd-40e18f6d0ead','{"id":"5a98bb93-6a4f-574f-a7dd-40e18f6d0ead","slug":"mediterranean","name":{"it":"Mediterranea","en":"Mediterranean"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Prioritises vegetables and legumes when compatible options are available.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('vegetarian','694e5085-04b8-5928-ad12-d5bbeead21ff','{"id":"694e5085-04b8-5928-ad12-d5bbeead21ff","slug":"vegetarian","name":{"it":"Vegetariana","en":"Vegetarian"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Excludes meat and fish according to the selected strictness.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('vegan','bb5baf42-5c10-5dbc-a908-89fa7a140b21','{"id":"bb5baf42-5c10-5dbc-a908-89fa7a140b21","slug":"vegan","name":{"it":"Vegana","en":"Vegan"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Excludes animal-derived catalog groups according to the selected strictness.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('pescatarian','fff5723c-7a1d-5241-93fb-dc452cf65833','{"id":"fff5723c-7a1d-5241-93fb-dc452cf65833","slug":"pescatarian","name":{"it":"Pescetariana","en":"Pescatarian"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Excludes meat while retaining fish according to the selected strictness.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('flexitarian','6f6d65e5-b3b7-5ddf-ba9e-1a633709a1fd','{"id":"6f6d65e5-b3b7-5ddf-ba9e-1a633709a1fd","slug":"flexitarian","name":{"it":"Flexitariana","en":"Flexitarian"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Prioritises plant foods without creating a hard meat exclusion.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('plant-forward','e6b0ee85-40e6-5727-bac3-fab54983b797','{"id":"e6b0ee85-40e6-5727-bac3-fab54983b797","slug":"plant-forward","name":{"it":"A prevalenza vegetale","en":"Plant-forward"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Prioritises plant foods without claiming a vegan diet.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('low-carb','3d405679-e8d6-5cf1-bbce-391ce12fe4bd','{"id":"3d405679-e8d6-5cf1-bbce-391ce12fe4bd","slug":"low-carb","name":{"it":"Preferenza low-carb","en":"Low-carb preference"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Records a preference only; no carbohydrate threshold is inferred.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('low-fat','ac40f335-36fb-5a48-9f35-47035ee9cae7','{"id":"ac40f335-36fb-5a48-9f35-47035ee9cae7","slug":"low-fat","name":{"it":"Preferenza low-fat","en":"Low-fat preference"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Records a preference only; no fat threshold is inferred.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('high-protein','0994b079-f1f8-51b0-bed1-6f4d569fc871','{"id":"0994b079-f1f8-51b0-bed1-6f4d569fc871","slug":"high-protein","name":{"it":"Proteica","en":"High protein"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"A ranking preference based on catalog food groups, not a nutrient target.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('whole-food','d1811ebc-6e7a-5582-a449-1e243b620fd8','{"id":"d1811ebc-6e7a-5582-a449-1e243b620fd8","slug":"whole-food","name":{"it":"Alimenti poco processati","en":"Whole-food focused"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Records a preference only when processing metadata is unavailable.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}'),
    ('gluten-free','5b759410-296d-59f6-9453-c595fd6a39da','{"id":"5b759410-296d-59f6-9453-c595fd6a39da","slug":"gluten-free","name":{"it":"Senza glutine","en":"Gluten free"},"medical":false,"is_demo":false,"status":"PUBLISHED","description":"Blocks foods catalogued as containing gluten.","self_declared":true,"clinical_limitations":"Product filtering profile; not medical advice or a safety guarantee."}')
)
INSERT INTO diet_definitions(id, slug, data)
SELECT id, slug, data FROM builtin
ON CONFLICT (slug) DO NOTHING;

WITH builtin(slug, version_id, rules) AS (
  VALUES
    ('balanced','3f051ecb-1239-5827-b505-623b33919c2e','[]'),
    ('omnivore','ce233f49-057f-5b4a-bd1f-47bdbba98c5b','[]'),
    ('mediterranean','09dcdf98-2dfa-530a-9d6e-02e9ee84184e','[{"type":"PREFER","groups":["vegetable","legume"],"hard_constraint":false}]'),
    ('vegetarian','135bdaa2-51f9-5c4d-be19-29bb3a35f0ec','[{"type":"EXCLUDE","groups":["meat","fish"],"hard_constraint":false}]'),
    ('vegan','1403f33c-9326-586d-97a8-05dc3b1dc732','[{"type":"EXCLUDE","groups":["meat","fish","dairy","egg","honey"],"hard_constraint":false}]'),
    ('pescatarian','62eb58a6-eae2-501d-b8d1-38a8f8a98852','[{"type":"EXCLUDE","groups":["meat"],"hard_constraint":false}]'),
    ('flexitarian','1ad38a69-2033-5150-9ddb-c6c3394f2de8','[{"type":"PREFER","groups":["vegetable","legume"],"hard_constraint":false}]'),
    ('plant-forward','074293ca-986d-576c-b0a6-d961f1c36cfc','[{"type":"PREFER","groups":["vegetable","legume"],"hard_constraint":false}]'),
    ('low-carb','fb5dd169-1f9a-5686-a220-9222abd9d6ae','[]'),
    ('low-fat','7fa24aca-4574-5e8a-87c5-106c588fdd43','[]'),
    ('high-protein','d2f6a861-7da8-5fd3-8039-62d9b505f140','[{"type":"PREFER","groups":["legume","meat","fish","egg","dairy"],"hard_constraint":false}]'),
    ('whole-food','e307c811-1d23-5f39-bb5c-37cd39683ed1','[]'),
    ('gluten-free','05ba5a9f-930d-5e47-9dba-f5d4d0988888','[{"type":"EXCLUDE","allergens":["gluten"],"hard_constraint":true}]')
)
INSERT INTO diet_versions(id, diet_id, version, status, effective_from, effective_until, rules)
SELECT
  b.version_id,
  d.id,
  COALESCE((SELECT MAX(v.version) + 1 FROM diet_versions v WHERE v.diet_id = d.id), 1),
  'PUBLISHED',
  '2026-01-01',
  NULL,
  b.rules
FROM builtin b
JOIN diet_definitions d ON d.slug = b.slug
WHERE NOT EXISTS (
  SELECT 1 FROM diet_versions v
  WHERE v.diet_id = d.id
    AND v.status = 'PUBLISHED'
);

COMMIT;
