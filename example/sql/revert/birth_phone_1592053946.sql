-- Revert example:birth_phone_1592053946 from pg

BEGIN;

-- Convert schema '' to '':;

BEGIN;

ALTER TABLE person DROP COLUMN birthday;

ALTER TABLE person DROP COLUMN phone_number;


COMMIT;



COMMIT;
