-- Récupère les ingrédients d'une recette
CREATE OR REPLACE FUNCTION api.recipe_ingredients(recipe api.recipe) RETURNS
SETOF api.ingredient_view AS $$
	SELECT *
	FROM api.ingredient_view
	WHERE ingredient_view.list_id = recipe.ingredient_list_id
$$ LANGUAGE SQL STABLE;


-- Récupère les ingrédients dans le frigo d'un utilisateur
CREATE OR REPLACE FUNCTION api.profile_fridge(profile api.profile) RETURNS
SETOF api.ingredient_view AS $$
	SELECT *
	FROM api.ingredient_view
	WHERE ingredient_view.list_id = profile.fridge_id
$$ LANGUAGE SQL STABLE;

-- Récupère les plannings d'un utilisateur
CREATE OR REPLACE FUNCTION api.profile_plannings(profile api.profile) RETURNS
SETOF api.planning AS $$
	SELECT *
	FROM api.planning
	WHERE api.planning.profile_id = profile.id
$$ LANGUAGE SQL STABLE;

-- Récupère les listes de courses d'un utilisateur
CREATE OR REPLACE FUNCTION api.profile_shopping_lists(profile api.profile) RETURNS
SETOF api.shopping_list AS $$
	SELECT *
	FROM api.shopping_list
	WHERE api.shopping_list.profile_id = profile.id
$$ LANGUAGE SQL STABLE;

-- Liste les catégories de premier niveau
CREATE OR REPLACE FUNCTION api.root_categories() RETURNS
SETOF api.category AS $$
	SELECT * FROM api.category
	WHERE parent_id IS NULL
$$ LANGUAGE SQL STABLE;

-- Liste les sous-catégories d'une catégorie
CREATE OR REPLACE FUNCTION api.category_children(parent api.category) RETURNS
SETOF api.category AS $$
	SELECT * FROM api.category 
	WHERE parent_id = parent.id 
	ORDER BY category.name
$$ LANGUAGE SQL STABLE;

-- Liste les recettes dans une catégorie
CREATE OR REPLACE FUNCTION api.category_recipes(category api.category) RETURNS
SETOF api.recipe AS $$
	SELECT recipe.*
	FROM internal.recipe_category
	LEFT JOIN api.recipe ON recipe_category.recipe_id = recipe.id
	WHERE recipe_category.category_id = category.id
$$ LANGUAGE SQL STABLE;

-- Liste les catégories d'une recette
CREATE OR REPLACE FUNCTION api.recipe_categories(recipe api.recipe) RETURNS
SETOF api.category AS $$
	SELECT category.*
	FROM internal.recipe_category
	LEFT JOIN api.category ON recipe_category.category_id = category.id
	WHERE recipe_category.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;


-- Liste les médias associés à une recette
CREATE OR REPLACE FUNCTION api.recipe_medias(recipe api.recipe) RETURNS
SETOF api.media AS $$
	SELECT media.*
	FROM internal.recipe_media
	LEFT JOIN api.media ON recipe_media.media_id = media.id
	WHERE recipe_media.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;

-- Récupère l'auteur d'une recette
CREATE OR REPLACE FUNCTION api.recipe_author(recipe api.recipe) RETURNS api.profile AS $$
	SELECT profile.*
	FROM api.profile
	WHERE profile.id = recipe.author_id
$$ LANGUAGE SQL STABLE;

-- Récupère les étapes d'une recette
CREATE OR REPLACE FUNCTION api.recipe_steps(recipe api.recipe) RETURNS
SETOF api.step AS $$
	SELECT step.*
	FROM api.step
	WHERE step.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;

-- Récupère les timers associés à une recette
CREATE OR REPLACE FUNCTION api.recipe_timers(recipe api.recipe) RETURNS
SETOF api.timer AS $$
	SELECT timer.*
	FROM internal.recipe_timer
	LEFT JOIN api.timer ON recipe_timer.timer_id = timer.id
	WHERE recipe_timer.recipe_id = recipe.id
$$ LANGUAGE SQL STABLE;

-- Récupère les recettes d'un utilisateur
CREATE OR REPLACE FUNCTION api.profile_recipes(profile api.profile) RETURNS
SETOF api.recipe AS $$
	SELECT *
	FROM api.recipe
	WHERE recipe.author_id = profile.id
$$ LANGUAGE SQL STABLE;

-- Récupère l'image de profile d'un utilisateur
CREATE OR REPLACE FUNCTION api.profile_picture(profile api.profile) RETURNS api.media AS $$
	SELECT *
	FROM api.media
	WHERE media.id = profile.picture_id
$$ LANGUAGE SQL STABLE;

-- Récupère le timer associé à une étape de recette
CREATE OR REPLACE FUNCTION api.step_timer(step api.step) RETURNS api.timer AS $$
	SELECT *
	FROM api.timer
	WHERE timer.id = step.timer_id
$$ LANGUAGE SQL STABLE;

-- Récupère l'image associée à une étape de recette
CREATE OR REPLACE FUNCTION api.step_media(step api.step) RETURNS api.media AS $$
	SELECT *
	FROM api.media
	WHERE media.id = step.media_id
$$ LANGUAGE SQL STABLE;


DROP FUNCTION IF EXISTS api.authenticate;
DROP TYPE IF EXISTS api.jwt_token CASCADE;

-- Un jeton d'authentification contient l'ID de l'utilisateur et son rôle postgres (admin ou authenticated)
CREATE TYPE api.jwt_token AS (role text, profile_id integer);

-- Authentifie un utilisateur (retourne un jeton d'authentification)
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


-- Enregistre un utilisateur, et retourne un jeton d'authentification
CREATE OR REPLACE FUNCTION api.register(username text, email text, password text, full_name text) RETURNS api.jwt_token AS $$
	DECLARE
		fridge_id integer;
		profile_id integer;
	BEGIN
		INSERT INTO internal.ingredient_list VALUES (DEFAULT) RETURNING id INTO fridge_id;
		INSERT INTO api.profile(username, email, password, full_name, fridge_id) VALUES ($1, $2, internal.crypt($3, internal.gen_salt('md5')), $4, fridge_id) RETURNING id INTO profile_id;
		RETURN ('authenticated', profile_id)::api.jwt_token;
	END;
$$ LANGUAGE plpgsql;


-- Fonction utilitaire pour avoir l'ID de l'utilisateur courant (à partir du jeton)
CREATE OR REPLACE FUNCTION internal.current_profile_id() RETURNS api.profile.id%type AS $$
	BEGIN
		RETURN current_setting('jwt.claims.profile_id');
	EXCEPTION WHEN OTHERS THEN
		RETURN null;
	END;
$$ LANGUAGE plpgsql STABLE;


-- Récupère le profile de l'utilisateur courant
CREATE OR REPLACE FUNCTION api.me() RETURNS api.profile AS $$
	SELECT *
	FROM api.profile
	WHERE profile.id = internal.current_profile_id()
$$ LANGUAGE sql STABLE;


DROP FUNCTION IF EXISTS api.auth_level;
DROP TYPE IF EXISTS api.user_level;

-- Niveau d'authentification d'un utilisateur
CREATE TYPE api.user_level AS ENUM ('anonymous', 'authenticated', 'admin');

-- Récupère le niveau d'authentification de l'utilisateur actuel
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


-- Récupère l'extension de fichier à partir de son type MIME
CREATE OR REPLACE FUNCTION api.mime_extension(m text) RETURNS TEXT as $$
	SELECT extension
	FROM api.mime_type
	WHERE mime = m
$$ LANGUAGE sql STABLE;

-- Génère le nom du fichier à partir de son hash et de son type MIME
CREATE OR REPLACE FUNCTION api.media_file(m api.media) RETURNS TEXT AS $$
	SELECT (encode(m.hash, 'hex') || '.' || api.mime_extension(m.mime));
$$ LANGUAGE SQL STABLE;

-- Recherche dans les recettes (nom + ingrédients)
CREATE OR REPLACE FUNCTION api.search(term text) RETURNS
SETOF api.recipe AS $$
	SELECT recipe.*
	FROM api.recipe
	INNER JOIN api.ingredient_view ingredient
	ON ingredient.list_id = recipe.ingredient_list_id
	WHERE to_tsvector(recipe.name || ' ' || recipe.description || ' ' || ingredient.name) @@ to_tsquery(term)
	GROUP BY recipe.id;
$$ LANGUAGE SQL STABLE;


-- Créé une recette pour l'utilisateur courant
CREATE OR REPLACE FUNCTION api.create_recipe() RETURNS api.recipe AS $$
	DECLARE
		profile_id integer;
		list_id integer;
		recipe api.recipe;
	BEGIN
		profile_id := internal.current_profile_id();
		INSERT INTO internal.ingredient_list VALUES (DEFAULT) RETURNING id INTO list_id;

		INSERT INTO api.recipe (author_id, ingredient_list_id) VALUES (profile_id, list_id)
		RETURNING * INTO recipe;

		RETURN recipe;
	END
$$ LANGUAGE plpgsql;


-- Met à jour les attributs d'une recette
CREATE OR REPLACE FUNCTION api.update_recipe(id integer, name text, description text, serves integer) RETURNS api.recipe AS $$
	DECLARE
		profile_id integer;
		value api.recipe;
	BEGIN
		SELECT * FROM api.recipe INTO value
		WHERE recipe.id = $1 and recipe.author_id = internal.current_profile_id();

		IF NOT FOUND THEN
			RAISE 'This is not your recipe.';
		ELSE
			UPDATE api.recipe SET (name, description, serves) = ($2, $3, $4)
			WHERE recipe.id = $1 RETURNING * INTO value;

			RETURN value;
		END IF;
	END;
$$ LANGUAGE plpgsql;


-- Ajoute un ingrédient à une recette
CREATE OR REPLACE FUNCTION api.add_ingredient(recipe_id integer, ingredient_name text, quantity float, unit text) RETURNS
SETOF api.ingredient_view AS $$
	DECLARE
		v_recipe api.recipe;
		v_ingredient internal.ingredient;
	BEGIN
		SELECT * FROM api.recipe INTO v_recipe WHERE recipe.id = $1 and recipe.author_id = internal.current_profile_id();
		IF NOT FOUND THEN
			RAISE 'This is not your recipe.';
		ELSE
			SELECT * FROM internal.ingredient INTO v_ingredient
			WHERE name ILIKE $2;

			IF NOT FOUND THEN
				INSERT INTO ingredient (name) VALUES ($2) RETURNING * INTO v_ingredient;
			END IF;

			INSERT INTO internal.ingredient_list_ingredient (list_id, ingredient_id, quantity, unit) VALUES (v_recipe.ingredient_list_id, v_ingredient.id, $3, $4);

			RETURN QUERY SELECT * FROM api.ingredient_view WHERE list_id = v_recipe.ingredient_list_id;
		END IF;
	END;
$$ LANGUAGE plpgsql;

-- Supprime un ingrédient d'une recette
CREATE OR REPLACE FUNCTION api.drop_ingredient(recipe_id integer, ingredient_id integer) RETURNS void AS $$
	DECLARE
		v_recipe api.recipe;
		v_ingredient internal.ingredient;
		v_ingredient_view api.ingredient_view;
	BEGIN
		SELECT * FROM api.recipe INTO v_recipe WHERE recipe.id = $1 and recipe.author_id = internal.current_profile_id();
		IF FOUND THEN
			DELETE FROM internal.ingredient_list_ingredient
			WHERE ingredient_list_ingredient.list_id = v_recipe.ingredient_list_id
			AND ingredient_list_ingredient.ingredient_id = $2;
		ELSE
			RAISE 'This is not your recipe.';
		END IF;
	END;
$$ LANGUAGE plpgsql;
