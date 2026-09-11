BEGIN;
INSERT INTO households VALUES ('household-a','00000000-0000-4000-8000-000000000001',1,'2026-09-10');
INSERT INTO households VALUES ('household-b','00000000-0000-4000-8000-000000000002',1,'2026-09-10');
INSERT INTO profiles VALUES ('00000000-0000-4000-8000-000000000001','A','household-a','{}',1,'2026-09-10');
INSERT INTO profiles VALUES ('00000000-0000-4000-8000-000000000002','B','household-b','{}',1,'2026-09-10');
INSERT INTO household_members VALUES ('household-a','00000000-0000-4000-8000-000000000001','owner');
INSERT INTO household_members VALUES ('household-b','00000000-0000-4000-8000-000000000002','owner');
INSERT INTO foods VALUES ('food-rls','{"is_demo":true}');
INSERT INTO inventory_batches VALUES ('batch-a','household-a','food-rls',1000,'fridge',NULL,'unknown',NULL,'manual',1,'2026-09-10','2026-09-10');
INSERT INTO inventory_batches VALUES ('batch-b','household-b','food-rls',1000,'fridge',NULL,'unknown',NULL,'manual',1,'2026-09-10','2026-09-10');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 IF (SELECT COUNT(*) FROM profiles)<>1 THEN RAISE EXCEPTION 'Profile leak'; END IF;
 IF (SELECT COUNT(*) FROM households)<>1 THEN RAISE EXCEPTION 'Household leak'; END IF;
 IF (SELECT COUNT(*) FROM inventory_batches)<>1 THEN RAISE EXCEPTION 'Inventory leak'; END IF;
 IF EXISTS(SELECT 1 FROM inventory_batches WHERE id='batch-b') THEN RAISE EXCEPTION 'Cross household read'; END IF;
 BEGIN
  UPDATE inventory_batches SET quantity_milli=0 WHERE id='batch-a';
  RAISE EXCEPTION 'Direct client write was permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM * FROM dev_sessions;
  RAISE EXCEPTION 'Development session table exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN
  PERFORM * FROM profiles;
  RAISE EXCEPTION 'Anonymous profile access';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
