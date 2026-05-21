-- ============================================================================
-- DIAGNÓSTICO: handle_new_user_registration
-- Ejecutar cada query por separado en el SQL Editor de Supabase
-- ============================================================================


-- ----------------------------------------------------------------------------
-- QUERY 1: Verificar que el fix llegó a Supabase
-- proconfig debe contener: {search_path=public,row_security=off}
-- Si es NULL → el CREATE OR REPLACE no se aplicó correctamente
-- ----------------------------------------------------------------------------
SELECT proname, proconfig
FROM pg_proc
WHERE proname = 'handle_new_user_registration';


-- ----------------------------------------------------------------------------
-- QUERY 2: Ver todos los triggers sobre auth.users
-- Buscar triggers duplicados o inesperados
-- ----------------------------------------------------------------------------
SELECT trigger_name, event_manipulation, action_timing, action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth' AND event_object_table = 'users';


-- ----------------------------------------------------------------------------
-- QUERY 3: Simular el trigger manualmente (se revierte, no deja datos)
-- Si lanza error → ese mensaje ES la causa raíz real
-- Si muestra NOTICE "OK" → el problema está en otro trigger
-- ----------------------------------------------------------------------------
BEGIN;
DO $$
DECLARE
    v_profile_id BIGINT;
    v_username   TEXT;
    v_fake_uid   UUID := gen_random_uuid();
BEGIN
    v_username := 'user_' || substring(replace(gen_random_uuid()::text, '-', ''), 1, 8);

    INSERT INTO public.profiles (user_id, username, full_name, avatar_url)
    VALUES (v_fake_uid, v_username, 'Test User', NULL)
    RETURNING id INTO v_profile_id;

    INSERT INTO public.profile_roles (profile_id, role_id)
    SELECT v_profile_id, id FROM public.roles WHERE name = 'user';

    RAISE NOTICE 'OK: profile_id=%, username=%', v_profile_id, v_username;
END;
$$;
ROLLBACK;


-- ----------------------------------------------------------------------------
-- QUERY 4: Ver columnas completas de profiles (incluyendo identity)
-- ----------------------------------------------------------------------------
SELECT column_name, is_nullable, column_default, data_type, is_identity, identity_generation
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;


-- ----------------------------------------------------------------------------
-- QUERY 5: Ver TODOS los constraints de profiles
-- Buscar FK, UNIQUE, CHECK que puedan estar bloqueando el INSERT
-- ----------------------------------------------------------------------------
SELECT conname, contype, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE t.relname = 'profiles' AND n.nspname = 'public';


-- ----------------------------------------------------------------------------
-- QUERY 6: Triggers sobre la tabla profiles (puede haber uno que falle)
-- ----------------------------------------------------------------------------
SELECT trigger_name, event_manipulation, action_timing, action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public' AND event_object_table = 'profiles';


-- ----------------------------------------------------------------------------
-- QUERY 7: Owner de la función (debe ser postgres para que row_security=off funcione)
-- ----------------------------------------------------------------------------
SELECT proname, proowner::regrole AS owner, prosecdef AS is_security_definer, proconfig
FROM pg_proc
WHERE proname = 'handle_new_user_registration';


-- ----------------------------------------------------------------------------
-- QUERY 8: TEST DEFINITIVO — insertar en auth.users directamente
-- Simula exactamente lo que hace GoTrue al crear un usuario.
-- Si lanza error → ese es el error REAL del trigger.
-- Si muestra "SUCCESS" → el problema NO es el trigger (es algo en Supabase Auth config).
-- SIEMPRE hace ROLLBACK, no deja datos.
-- ----------------------------------------------------------------------------
BEGIN;
DO $$
DECLARE
    v_test_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (
        id, email, raw_user_meta_data, raw_app_meta_data,
        aud, role, created_at, updated_at, encrypted_password
    ) VALUES (
        v_test_id,
        'diag_' || replace(v_test_id::text, '-', '') || '@test.com',
        '{"username": "diagtest", "full_name": "Diag Test"}'::jsonb,
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        'authenticated',
        'authenticated',
        now(),
        now(),
        ''
    );

    IF EXISTS (SELECT 1 FROM public.profiles WHERE user_id = v_test_id) THEN
        RAISE NOTICE 'SUCCESS: trigger fired and profile was created for %', v_test_id;
    ELSE
        RAISE NOTICE 'PROBLEM: auth.users insert succeeded but NO profile was created';
    END IF;
END;
$$;
ROLLBACK;
