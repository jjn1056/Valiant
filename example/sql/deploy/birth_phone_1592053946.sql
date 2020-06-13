-- Deploy example:birth_phone_1592053946 to pg

BEGIN;

-- Convert schema '' to '':;

BEGIN;

ALTER TABLE person ADD COLUMN birthday date;

ALTER TABLE person ADD COLUMN phone_number character varying(32);


COMMIT;



COMMIT;
