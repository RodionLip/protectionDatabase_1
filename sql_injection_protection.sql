-- =====================================================
-- Защита от SQL-инъекций для БД online_learning_v2
-- =====================================================
-- Безопасные хранимые функции с параметризацией и
-- белыми списками для таблиц схемы app.
-- =====================================================


-- =====================================================
-- БЕЗОПАСНАЯ АУТЕНТИФИКАЦИЯ (app.users)
-- Защита: параметризованный запрос ($1, $2)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_login(
    p_username TEXT,
    p_password_hash TEXT
)
RETURNS TABLE(
    user_id INTEGER,
    username VARCHAR,
    full_name VARCHAR,
    is_active BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT u.user_id, u.username, u.full_name, u.is_active
    FROM app.users u
    WHERE u.username = p_username
      AND u.password_hash = p_password_hash;
$$;


-- =====================================================
-- БЕЗОПАСНЫЙ ПОИСК КУРСОВ (app.courses)
-- Защита: параметризованный запрос ($1)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_search_courses(
    p_keyword TEXT
)
RETURNS TABLE(
    course_id INTEGER,
    title VARCHAR,
    description TEXT,
    price DECIMAL,
    status VARCHAR
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT c.course_id, c.title, c.description, c.price, c.status
    FROM app.courses c
    WHERE c.title ILIKE '%' || p_keyword || '%'
      AND c.status = 'published';
$$;


-- =====================================================
-- БЕЗОПАСНАЯ ВЫБОРКА ЗАЧИСЛЕНИЙ (app.enrollments)
-- Защита: параметризация + строгая типизация INTEGER
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_get_enrollments(
    p_user_id INTEGER
)
RETURNS TABLE(
    enrollment_id INTEGER,
    course_title VARCHAR,
    enrollment_status VARCHAR,
    enrolled_at TIMESTAMP
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT e.enrollment_id, c.title, e.status, e.enrolled_at
    FROM app.enrollments e
    JOIN app.courses c ON c.course_id = e.course_id
    WHERE e.user_id = p_user_id;
$$;


-- =====================================================
-- БЕЗОПАСНАЯ СОРТИРОВКА КУРСОВ (app.courses)
-- Защита: белый список полей и направлений (CASE)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_list_courses(
    p_sort_field TEXT DEFAULT 'created_at',
    p_sort_direction TEXT DEFAULT 'DESC'
)
RETURNS TABLE(
    course_id INTEGER,
    title VARCHAR,
    price DECIMAL,
    status VARCHAR,
    created_at TIMESTAMP
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
    v_field TEXT;
    v_direction TEXT;
BEGIN
    v_field := CASE p_sort_field
        WHEN 'title'      THEN 'title'
        WHEN 'price'      THEN 'price'
        WHEN 'status'     THEN 'status'
        WHEN 'created_at' THEN 'created_at'
        ELSE 'created_at'
    END;

    v_direction := CASE LOWER(p_sort_direction)
        WHEN 'asc'  THEN 'ASC'
        WHEN 'desc' THEN 'DESC'
        ELSE 'DESC'
    END;

    RETURN QUERY EXECUTE
        format(
            'SELECT course_id, title, price, status, created_at '
            'FROM app.courses '
            'WHERE status = ''published'' '
            'ORDER BY %I %s',
            v_field, v_direction
        );
END;
$$;


-- =====================================================
-- БЕЗОПАСНАЯ РАБОТА С ФОРУМОМ (app.forum_posts)
-- Защита: параметризованный запрос ($1, $2)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_get_forum_posts(
    p_course_id INTEGER,
    p_moderated BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    post_id INTEGER,
    title VARCHAR,
    content TEXT,
    created_at TIMESTAMP
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT fp.post_id, fp.title, fp.content, fp.created_at
    FROM app.forum_posts fp
    WHERE fp.course_id = p_course_id
      AND fp.is_moderated = p_moderated
    ORDER BY fp.created_at DESC;
$$;


-- =====================================================
-- БЕЗОПАСНАЯ ОТПРАВКА РАБОТЫ (app.submissions)
-- Защита: параметризованный запрос ($1, $2, $3)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_submit_assignment(
    p_assignment_id INTEGER,
    p_user_id INTEGER,
    p_content TEXT
)
RETURNS TABLE(
    submission_id INTEGER
)
LANGUAGE sql SECURITY DEFINER
AS $$
    INSERT INTO app.submissions (assignment_id, user_id, content)
    VALUES (p_assignment_id, p_user_id, p_content)
    RETURNING submission_id;
$$;


-- =====================================================
-- БЕЗОПАСНОЕ ОБНОВЛЕНИЕ СТАТУСА ЗАЧИСЛЕНИЯ (app.enrollments)
-- Защита: белый список допустимых статусов (CASE)
-- =====================================================

CREATE OR REPLACE FUNCTION app.safe_update_enrollment_status(
    p_enrollment_id INTEGER,
    p_user_id INTEGER,
    p_new_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_status TEXT;
BEGIN
    v_status := CASE p_new_status
        WHEN 'active'    THEN 'active'
        WHEN 'completed' THEN 'completed'
        WHEN 'dropped'   THEN 'dropped'
        ELSE NULL
    END;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Недопустимый статус: %', p_new_status;
    END IF;

    UPDATE app.enrollments
    SET status = v_status
    WHERE enrollment_id = p_enrollment_id
      AND user_id = p_user_id;

    RETURN FOUND;
END;
$$;


-- =====================================================
-- ОГРАНИЧЕННАЯ РОЛЬ ПРИЛОЖЕНИЯ
-- =====================================================

DROP ROLE IF EXISTS web_app_secure;
CREATE ROLE web_app_secure LOGIN PASSWORD 'SecureApp2024!';

GRANT USAGE ON SCHEMA app TO web_app_secure;

GRANT SELECT ON app.users TO web_app_secure;
GRANT SELECT ON app.courses TO web_app_secure;
GRANT SELECT ON app.lessons TO web_app_secure;
GRANT SELECT ON app.assignments TO web_app_secure;
GRANT SELECT ON app.enrollments TO web_app_secure;
GRANT SELECT ON app.submissions TO web_app_secure;
GRANT SELECT ON app.forum_posts TO web_app_secure;
GRANT SELECT ON app.certificates TO web_app_secure;

GRANT INSERT ON app.submissions TO web_app_secure;
GRANT UPDATE (status) ON app.enrollments TO web_app_secure;
GRANT INSERT ON app.forum_posts TO web_app_secure;
GRANT UPDATE (content, updated_at) ON app.forum_posts TO web_app_secure;
GRANT USAGE ON SEQUENCE app.submissions_submission_id_seq TO web_app_secure;
GRANT USAGE ON SEQUENCE app.forum_posts_post_id_seq TO web_app_secure;

GRANT EXECUTE ON FUNCTION app.safe_login(TEXT, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_search_courses(TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_get_enrollments(INTEGER) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_list_courses(TEXT, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_get_forum_posts(INTEGER, BOOLEAN) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_submit_assignment(INTEGER, INTEGER, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_update_enrollment_status(INTEGER, INTEGER, TEXT) TO web_app_secure;

GRANT INSERT ON app.access_logs TO web_app_secure;
GRANT USAGE ON SEQUENCE app.access_logs_log_id_seq TO web_app_secure;


-- =====================================================
-- ПРОВЕРКА ПРАВ РОЛИ web_app_secure
-- =====================================================

SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'web_app_secure'
ORDER BY table_name, privilege_type;


-- =====================================================
-- ПРОВЕРКА РАБОТЫ ЗАЩИТЫ
-- =====================================================

-- === От суперпользователя (postgres) ===
-- psql -U postgres -d online_learning_v2

-- Корректный логин:
SELECT * FROM app.safe_login('student1', 'hash1');
-- Результат: 1 строка (student1)

-- Попытка инъекции в логине:
SELECT * FROM app.safe_login(''' OR 1=1 --', 'anything');
-- Результат: 0 строк — инъекция заблокирована

-- Корректный поиск курсов:
SELECT * FROM app.safe_search_courses('Python');
-- Результат: 1 строка (Основы Python)

-- Попытка инъекции в поиске:
SELECT * FROM app.safe_search_courses(''' OR 1=1 --');
-- Результат: 0 строк — инъекция заблокирована

-- Корректная сортировка:
SELECT * FROM app.safe_list_courses('price', 'asc');
-- Результат: опубликованные курсы по возрастанию цены

-- Попытка инъекции в сортировке:
SELECT * FROM app.safe_list_courses('title; DROP TABLE app.users; --', 'asc');
-- Результат: сортировка по created_at DESC (значение по умолчанию) — атака отброшена

-- Зачисления student1:
SELECT * FROM app.safe_get_enrollments(1);
-- Результат: курсы student1

-- Обновление статуса — корректное:
SELECT app.safe_update_enrollment_status(1, 1, 'completed');
-- Результат: true

-- Обновление статуса — вредоносное:
SELECT app.safe_update_enrollment_status(1, 1, 'hacked''; DROP TABLE app.users; --');
-- Результат: ERROR: Недопустимый статус


-- === От student1 ===
-- psql -U student1 -d online_learning_v2 -W
-- Пароль: StudentPass123

SELECT * FROM app.safe_login('student1', 'hash1');
-- Результат: 1 строка

SELECT * FROM app.safe_login(''' OR 1=1 --', 'x');
-- Результат: 0 строк

SELECT * FROM app.safe_search_courses('Python');
-- Результат: 1 строка

SELECT * FROM app.safe_get_enrollments(1);
-- Результат: зачисления student1

SELECT * FROM app.users;
-- Результат: только своя строка (RLS)

-- DROP TABLE app.users;
-- Результат: ERROR: must be owner of table users


-- === От teacher1 ===
-- psql -U teacher1 -d online_learning_v2 -W
-- Пароль: TeacherPass123

SELECT * FROM app.safe_login('teacher1', 'hash3');
-- Результат: 1 строка

SELECT * FROM app.safe_search_courses('Веб');
-- Результат: 1 строка (Веб-разработка)

SELECT * FROM app.safe_list_courses('title', 'asc');
-- Результат: опубликованные курсы по алфавиту

SELECT * FROM app.safe_list_courses('price; DELETE FROM app.users; --', 'desc');
-- Результат: сортировка по created_at DESC — атака отброшена

SELECT app.safe_update_enrollment_status(1, 1, 'completed');
-- Результат: true

SELECT app.safe_update_enrollment_status(1, 1, 'hacked''; DROP TABLE app.users; --');
-- Результат: ERROR: Недопустимый статус


-- === От admin1 ===
-- psql -U admin1 -d online_learning_v2 -W
-- Пароль: AdminPass777

SELECT user_id, username, full_name FROM app.users;
-- Результат: все 8 пользователей (RLS разрешает админу)

SELECT * FROM app.safe_login('admin1', 'hash8');
-- Результат: 1 строка

SELECT * FROM app.safe_search_courses('Java');
-- Результат: 0 строк (Java-разработчик archived, не published)

SELECT * FROM app.safe_list_courses('price', 'desc');
-- Результат: опубликованные курсы по убыванию цены


-- === От web_app_secure (роль приложения) ===
-- psql -U web_app_secure -d online_learning_v2 -W
-- Пароль: SecureApp2024!

SELECT * FROM app.safe_login('student1', 'hash1');
-- Результат: 1 строка

SELECT * FROM app.safe_search_courses('Python');
-- Результат: 1 строка

-- DELETE FROM app.users WHERE user_id = 1;
-- Результат: ERROR: permission denied for table users

-- UPDATE app.users SET password_hash = 'hacked' WHERE username = 'admin1';
-- Результат: ERROR: permission denied for table users

-- DROP TABLE app.courses;
-- Результат: ERROR: must be owner of table courses
