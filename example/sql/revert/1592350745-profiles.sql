-- Revert example:1592350745-profiles from pg

BEGIN;

-- Convert schema '' to '':;

BEGIN;

ALTER TABLE person DROP CONSTRAINT person_fk_state_id;

ALTER TABLE person ADD COLUMN address character varying(48) NOT NULL;

ALTER TABLE person ADD COLUMN city character varying(32) NOT NULL;

ALTER TABLE person ADD COLUMN zip character varying(5) NOT NULL;

ALTER TABLE person ADD COLUMN state_id integer NOT NULL;

ALTER TABLE person ADD COLUMN birthday date;

ALTER TABLE person ADD COLUMN phone_number character varying(32);

ALTER TABLE person ADD CONSTRAINT person_fk_state_id FOREIGN KEY (state_id)
  REFERENCES state (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;

DROP TABLE profile CASCADE;


COMMIT;



COMMIT;
