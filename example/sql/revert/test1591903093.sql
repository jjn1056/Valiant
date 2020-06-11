-- Revert example:test1591903093 from pg

BEGIN;

-- Convert schema '' to '':;

BEGIN;

ALTER TABLE credit_card DROP CONSTRAINT credit_card_fk_person_id;

ALTER TABLE credit_card ADD CONSTRAINT credit_card_fk_person_id FOREIGN KEY (person_id)
  REFERENCES state (id) DEFERRABLE;

DROP TABLE person_role CASCADE;

DROP TABLE role CASCADE;


COMMIT;



COMMIT;
