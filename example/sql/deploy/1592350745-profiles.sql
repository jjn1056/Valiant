-- Deploy example:1592350745-profiles to pg


BEGIN;

CREATE TABLE "profile" (
  "id" bigserial NOT NULL,
  "person_id" integer NOT NULL,
  "state_id" integer NOT NULL,
  "address" character varying(48) NOT NULL,
  "city" character varying(32) NOT NULL,
  "zip" character varying(5) NOT NULL,
  "birthday" date,
  "phone_number" character varying(32),
  PRIMARY KEY ("id"),
  CONSTRAINT "profile_id_person_id" UNIQUE ("id", "person_id")
);
CREATE INDEX "profile_idx_person_id" on "profile" ("person_id");
CREATE INDEX "profile_idx_state_id" on "profile" ("state_id");

ALTER TABLE "profile" ADD CONSTRAINT "profile_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "state" ("id") DEFERRABLE;

ALTER TABLE "profile" ADD CONSTRAINT "profile_fk_state_id" FOREIGN KEY ("state_id")
  REFERENCES "state" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE person DROP CONSTRAINT person_fk_state_id;

ALTER TABLE person DROP COLUMN address;

ALTER TABLE person DROP COLUMN city;

ALTER TABLE person DROP COLUMN zip;

ALTER TABLE person DROP COLUMN state_id;

ALTER TABLE person DROP COLUMN birthday;

ALTER TABLE person DROP COLUMN phone_number;

COMMIT;

