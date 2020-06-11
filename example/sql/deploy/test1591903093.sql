-- Deploy example:test1591903093 to pg

BEGIN;

-- Convert schema '' to '':;


CREATE TABLE "person_role" (
  "person_id" integer NOT NULL,
  "role_id" integer NOT NULL,
  PRIMARY KEY ("person_id", "role_id")
);
CREATE INDEX "person_role_idx_person_id" on "person_role" ("person_id");
CREATE INDEX "person_role_idx_role_id" on "person_role" ("role_id");

CREATE TABLE "role" (
  "id" serial NOT NULL,
  "label" character varying(24) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "role_label" UNIQUE ("label")
);

ALTER TABLE "person_role" ADD CONSTRAINT "person_role_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "person" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE "person_role" ADD CONSTRAINT "person_role_fk_role_id" FOREIGN KEY ("role_id")
  REFERENCES "role" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;


insert into role(label) values('administrator'),
  ('user'),
  ('power-user');
  
COMMIT;
