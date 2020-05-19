CREATE TABLE "state" (
  "id" serial NOT NULL,
  "name" character varying(24) NOT NULL,
  "abbreviation" character varying(24) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "state_abbreviation" UNIQUE ("abbreviation"),
  CONSTRAINT "state_name" UNIQUE ("name")
);

CREATE TABLE "credit_card" (
  "id" serial NOT NULL,
  "person_id" integer NOT NULL,
  "card_number" character varying(20) NOT NULL,
  "expiration" date NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "credit_card_idx_person_id" on "credit_card" ("person_id");

CREATE TABLE "person" (
  "id" bigserial NOT NULL,
  "username" character varying(48) NOT NULL,
  "first_name" character varying(24) NOT NULL,
  "last_name" character varying(48) NOT NULL,
  "address" character varying(48) NOT NULL,
  "city" character varying(32) NOT NULL,
  "zip" character varying(5) NOT NULL,
  "state_id" integer NOT NULL,
  "password" character varying(64) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "person_username" UNIQUE ("username")
);
CREATE INDEX "person_idx_state_id" on "person" ("state_id");

ALTER TABLE "credit_card" ADD CONSTRAINT "credit_card_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "state" ("id") DEFERRABLE;

ALTER TABLE "person" ADD CONSTRAINT "person_fk_state_id" FOREIGN KEY ("state_id")
  REFERENCES "state" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

