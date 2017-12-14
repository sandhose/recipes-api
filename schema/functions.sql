CREATE OR REPLACE FUNCTION api.recipe_ingredients(recipe api.recipe) RETURNS
SETOF api.ingredient_view AS $$
	SELECT *
	FROM api.ingredient_view
	WHERE ingredient_view.list_id = recipe.ingredient_list_id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.profile_fridge(profile api.profile) RETURNS
SETOF api.ingredient_view AS $$
	SELECT *
	FROM api.ingredient_view
	WHERE ingredient_view.list_id = profile.fridge_id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.profile_plannings(profile api.profile) RETURNS
SETOF api.planning AS $$
	SELECT *
	FROM api.planning
	WHERE api.planning.profile_id = profile.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.profile_shopping_lists(profile api.profile) RETURNS
SETOF api.shopping_list AS $$
	SELECT *
	FROM api.shopping_list
	WHERE api.shopping_list.profile_id = profile.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.root_categories() RETURNS
SETOF api.category AS $$
	SELECT * FROM api.category WHERE parent_id IS NULL
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.category_children(parent api.category) RETURNS
SETOF api.category AS $$
	SELECT * FROM api.category WHERE parent_id = parent.id ORDER BY category.name
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.category_recipes(category api.category) RETURNS
SETOF api.recipe AS $$
	SELECT recipe.*
	FROM internal.recipe_category
	LEFT JOIN api.recipe ON recipe_category.recipe_id = recipe.id
	WHERE recipe_category.category_id = category.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.recipe_categories(recipe api.recipe) RETURNS
SETOF api.category AS $$
	SELECT category.*
	FROM internal.recipe_category
	LEFT JOIN api.category ON recipe_category.category_id = category.id
	WHERE recipe_category.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.recipe_media(recipe api.recipe) RETURNS
SETOF api.media AS $$
	SELECT media.*
	FROM internal.recipe_media
	LEFT JOIN api.media ON recipe_media.media_id = media.id
	WHERE recipe_media.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.recipe_timers(recipe api.recipe) RETURNS
SETOF api.timer AS $$
	SELECT timer.*
	FROM internal.recipe_timer
	LEFT JOIN api.timer ON recipe_timer.recipe_id = timer.id
	WHERE recipe_timer.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.profile_recipes(profile api.profile) RETURNS
SETOF api.recipe AS $$
	SELECT *
	FROM api.recipe
	WHERE recipe.author_id = profile.id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.profile_picture(profile api.profile) RETURNS api.media AS $$
	SELECT *
	FROM api.media
	WHERE media.id = profile.picture_id
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION api.step_media(step api.step) RETURNS api.media AS $$
	SELECT *
	FROM api.media
	WHERE media.id = step.media_id
$$ LANGUAGE SQL STABLE;


DROP FUNCTION IF EXISTS api.authenticate;


DROP TYPE IF EXISTS api.jwt_token CASCADE;


CREATE TYPE api.jwt_token AS (role text, profile_id integer);


CREATE OR REPLACE FUNCTION api.authenticate(username text, password text) RETURNS api.jwt_token AS $$
	DECLARE
		profile api.profile;
	BEGIN
		SELECT p.* INTO profile
		FROM api.profile AS p
		WHERE p.username = $1;

		IF profile.password = internal.crypt($2, profile.password) THEN
			IF profile.is_admin THEN
				RETURN ('admin', profile.id)::api.jwt_token;
			ELSE
				RETURN ('authenticated', profile.id)::api.jwt_token;
			END IF;
		ELSE
			RETURN NULL;
		END IF;
	END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION internal.current_profile_id() RETURNS api.profile.id%type AS $$
	BEGIN
		RETURN current_setting('jwt.claims.profile_id');
	EXCEPTION WHEN OTHERS THEN
		RETURN null;
	END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION api.me() RETURNS api.profile AS $$
	SELECT *
	FROM api.profile
	WHERE profile.id = internal.current_profile_id()
$$ LANGUAGE sql STABLE;


DROP FUNCTION IF EXISTS api.auth_level;


DROP TYPE IF EXISTS api.user_level;


CREATE TYPE api.user_level AS ENUM ('anonymous', 'authenticated', 'admin');


CREATE OR REPLACE FUNCTION api.auth_level() RETURNS api.user_level AS $$
	SELECT COALESCE(
		(
			SELECT CASE
				WHEN profile.is_admin THEN 'admin'
				ELSE 'authenticated'
			END
			FROM api.profile
			WHERE profile.id = internal.current_profile_id()
		),
		'anonymous'
	)::api.user_level
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION api.mime_extension(m text) RETURNS TEXT as $$
	SELECT extension
	FROM api.mime_type
	WHERE mime = m
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION api.media_file(m api.media) RETURNS TEXT AS $$
	SELECT (encode(m.hash, 'hex') || '.' || api.mime_extension(m.mime));
$$ LANGUAGE SQL STABLE;

