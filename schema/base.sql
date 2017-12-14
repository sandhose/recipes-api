CREATE SCHEMA internal;

CREATE SCHEMA api;

CREATE EXTENSION pgcrypto SCHEMA internal;

-- REVOKE ALL PRIVILEGES ON DATABASE recipes2 FROM admin;
-- REVOKE ALL PRIVILEGES ON DATABASE recipes2 FROM authenticated;
-- REVOKE ALL PRIVILEGES ON DATABASE recipes2 FROM anonymous;
-- DROP ROLE admin;
-- DROP ROLE authenticated;
-- DROP OWNED BY anonymous CASCADE;
-- DROP ROLE anonymous;

CREATE ROLE admin;
CREATE ROLE authenticated;
CREATE ROLE anonymous;

GRANT anonymous TO authenticated;
GRANT authenticated TO admin;

GRANT USAGE ON SCHEMA api TO anonymous;
GRANT USAGE ON SCHEMA internal TO anonymous;
GRANT SELECT ON ALL TABLES IN SCHEMA api TO anonymous;
GRANT SELECT ON ALL TABLES IN SCHEMA internal TO anonymous;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO anonymous;

CREATE TABLE IF NOT EXISTS api.mime_type (
	mime text PRIMARY KEY,
	extension text NOT NULL
);

INSERT INTO api.mime_type VALUES
	('image/gif', 'gif'), 
	('image/jpeg', 'jpg'),
	('image/png', 'png');

CREATE TABLE IF NOT EXISTS api.media (
	id serial PRIMARY KEY,
	hash bytea NOT NULL,
	name text,
	mime text REFERENCES api.mime_type ON DELETE SET NULL
);



CREATE TABLE IF NOT EXISTS api.category (
	id serial PRIMARY KEY,
	parent_id integer REFERENCES api.category ON DELETE SET NULL,
	name text,
	description text,
	media_id integer REFERENCES api.media ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS internal.ingredient (
	id serial PRIMARY KEY,
	name text,
	description text
);

CREATE TABLE IF NOT EXISTS internal.ingredient_media (
	media_id integer NOT NULL REFERENCES api.media ON DELETE CASCADE,
	ingredient_id integer NOT NULL REFERENCES internal.ingredient ON DELETE CASCADE,
	PRIMARY KEY (media_id, ingredient_id)
);

CREATE TABLE IF NOT EXISTS api.diet (
	id serial PRIMARY KEY,
	name text
);

CREATE TABLE IF NOT EXISTS internal.diet_intolerance (
	diet_id integer NOT NULL REFERENCES api.diet ON DELETE CASCADE,
	ingredient_id integer NOT NULL REFERENCES internal.ingredient ON DELETE CASCADE,
	PRIMARY KEY (diet_id, ingredient_id)
);


CREATE TABLE IF NOT EXISTS internal.ingredient_list (
	id serial PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS internal.ingredient_list_ingredient (
	list_id integer NOT NULL REFERENCES internal.ingredient_list ON DELETE CASCADE,
	ingredient_id integer NOT NULL REFERENCES internal.ingredient ON DELETE RESTRICT,
	quantity float DEFAULT 1.,
	unit text,
	PRIMARY KEY (list_id, ingredient_id)
);

CREATE TABLE IF NOT EXISTS api.profile (
	id serial PRIMARY KEY,
	username text,
	email text,
	password text,
	full_name text,
	biography text,
	picture_id integer REFERENCES api.media ON DELETE SET NULL,
	fridge_id integer NOT NULL REFERENCES internal.ingredient_list ON DELETE RESTRICT,
	is_admin boolean NOT NULL DEFAULT false,

	CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

CREATE TABLE IF NOT EXISTS api.shopping_list (
	ingredient_list_id integer NOT NULL REFERENCES internal.ingredient_list ON DELETE RESTRICT,
	profile_id integer REFERENCES api.profile ON DELETE CASCADE,
	expiry_date date
);

CREATE TABLE IF NOT EXISTS api.recipe (
	id serial PRIMARY KEY,
	name text,
	description text,
	author_id integer REFERENCES api.profile ON DELETE SET NULL,
	ingredient_list_id integer REFERENCES internal.ingredient_list ON DELETE CASCADE,
	serves integer,
	calories integer
);

CREATE TABLE IF NOT EXISTS internal.recipe_category (
	recipe_id integer REFERENCES api.recipe,
	category_id integer REFERENCES api.category,
	PRIMARY KEY (recipe_id, category_id)
);

CREATE TABLE IF NOT EXISTS internal.recipe_media (
	media_id integer REFERENCES api.media ON DELETE CASCADE,
	recipe_id integer REFERENCES api.recipe ON DELETE CASCADE,
	PRIMARY KEY (media_id, recipe_id)
);

CREATE TABLE IF NOT EXISTS api.timer (
	id serial PRIMARY KEY,
	time_min integer,
	time_max integer,
	type character varying(16) -- TODO: ENUM?
);

CREATE TABLE IF NOT EXISTS internal.recipe_timer (
	recipe_id integer NOT NULL REFERENCES api.recipe ON DELETE CASCADE,
	timer_id integer NOT NULL REFERENCES api.timer ON DELETE CASCADE,
	PRIMARY KEY (recipe_id, timer_id)
);

CREATE TABLE IF NOT EXISTS api.step (
	id serial PRIMARY KEY,
	recipe_id integer REFERENCES api.recipe ON DELETE CASCADE,
	description text,
	"position" integer NOT NULL,
	media_id integer REFERENCES api.media ON DELETE SET NULL,
	timer_id integer REFERENCES api.timer ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS api.menu (
	id serial PRIMARY KEY,
	name text
);

CREATE TABLE IF NOT EXISTS internal.menu_recipe (
	menu_id integer NOT NULL REFERENCES api.menu ON DELETE CASCADE,
	recipe_id integer REFERENCES api.recipe ON DELETE SET NULL,
	"position" integer NOT NULL,
	PRIMARY KEY (menu_id, recipe_id)
);

CREATE TABLE IF NOT EXISTS api.planning (
	id serial PRIMARY KEY,
	name text,
	profile_id integer NOT NULL REFERENCES api.profile ON DELETE CASCADE,
	expiry_date date
);

CREATE TABLE IF NOT EXISTS internal.planning_menu (
	planning_id integer NOT NULL REFERENCES api.planning ON DELETE CASCADE,
	menu_id integer NOT NULL REFERENCES api.menu ON DELETE CASCADE,
	"position" integer NOT NULL
);

CREATE OR REPLACE VIEW api.ingredient_view AS
	SELECT
		ingredient.id,
		ingredient.name,
		ingredient.description,
		ingredient_list_ingredient.list_id,
		ingredient_list_ingredient.ingredient_id,
		ingredient_list_ingredient.quantity,
		ingredient_list_ingredient.unit
	FROM internal.ingredient_list_ingredient
	INNER JOIN internal.ingredient
		ON ingredient_list_ingredient.ingredient_id = ingredient.id;

CREATE OR REPLACE VIEW api.planning_menu_view AS
	SELECT
		menu.id, 
		menu.name,
		planning_menu.position
	FROM api.menu
	INNER JOIN internal.planning_menu
		ON planning_menu.menu_id = menu.id;

