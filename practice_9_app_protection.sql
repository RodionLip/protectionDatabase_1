-- =====================================================
-- ПРАКТИКА 9 (ДОПОЛНЕНИЕ): Защита от SQL-инъекций
-- для существующей схемы app (online_learning_v2)
-- =====================================================
-- Применяем те же принципы защиты (параметризация,
-- белые списки, минимальные привилегии) к реальным
-- таблицам нашей БД: app.users, app.courses и т.д.
-- =====================================================


-- =====================================================
-- ЧАСТЬ A: УЯЗВИМЫЕ ПРИМЕРЫ НА ОСНОВЕ СХЕМЫ APP
-- =====================================================
-- Ниже показаны типичные уязвимые фрагменты кода,
-- которые могли бы использоваться в приложении
-- для работы с нашими таблицами.

-- =====================================================
-- A.1: Уязвимая аутентификация (app.users)
-- =====================================================

-- УЯЗВИМЫЙ КОД (JavaScript / Node.js):
--
-- async function loginUser(client, username, passwordHash) {
--   const sql =
--     "SELECT user_id, username, full_name, is_active " +
--     "FROM app.users " +
--     "WHERE username = '" + username + "' " +
--     "AND password_hash = '" + passwordHash + "'";
--
--   return client.query(sql);
-- }

-- Пример атаки:
-- username: admin1' --
-- passwordHash: (любой)
-- Итоговый запрос:
-- SELECT user_id, username, full_name, is_active
-- FROM app.users
-- WHERE username = 'admin1' --' AND password_hash = 'любой'
-- Результат: вход под admin1 без пароля!

-- Ещё опаснее — получить всех пользователей:
-- username: ' OR 1=1 --
-- Итоговый запрос:
-- SELECT user_id, username, full_name, is_active
-- FROM app.users
-- WHERE username = '' OR 1=1 --' AND password_hash = '...'
-- Результат: ВСЕ пользователи


-- =====================================================
-- A.2: Уязвимый поиск курсов (app.courses)
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function searchCourses(client, keyword) {
--   const sql =
--     "SELECT course_id, title, description, price, status " +
--     "FROM app.courses " +
--     "WHERE title ILIKE '%" + keyword + "%' " +
--     "AND status = 'published'";
--
--   return client.query(sql);
-- }

-- Пример атаки — получить ВСЕ курсы (включая draft и archived):
-- keyword: %' OR 1=1 --
-- Итоговый запрос:
-- SELECT course_id, title, description, price, status
-- FROM app.courses
-- WHERE title ILIKE '%%' OR 1=1 --% AND status = 'published'
-- Результат: все 4 курса, включая draft и archived


-- =====================================================
-- A.3: Уязвимая выборка зачислений (app.enrollments)
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function getEnrollments(client, userId) {
--   const sql =
--     "SELECT e.enrollment_id, c.title, e.status, e.enrolled_at " +
--     "FROM app.enrollments e " +
--     "JOIN app.courses c ON c.course_id = e.course_id " +
--     "WHERE e.user_id = " + userId;
--
--   return client.query(sql);
-- }

-- Пример атаки — получить зачисления ВСЕХ пользователей:
-- userId: 1 OR 1=1
-- Итоговый запрос:
-- SELECT ... FROM app.enrollments e JOIN app.courses c ...
-- WHERE e.user_id = 1 OR 1=1
-- Результат: ВСЕ зачисления всех пользователей

-- Более опасная атака — UNION для извлечения паролей:
-- userId: 0 UNION SELECT 1, password_hash, username, now() FROM app.users --
-- Результат: утечка хешей паролей!


-- =====================================================
-- A.4: Уязвимая сортировка курсов (ORDER BY)
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function listCourses(client, sortBy, order) {
--   const sql =
--     "SELECT course_id, title, price, status, created_at " +
--     "FROM app.courses " +
--     "WHERE status = 'published' " +
--     "ORDER BY " + sortBy + " " + order;
--
--   return client.query(sql);
-- }

-- Пример атаки:
-- sortBy: (SELECT password_hash FROM app.users WHERE username='admin1')
-- Результат: утечка данных через сортировку


-- =====================================================
-- A.5: Уязвимая фильтрация постов форума (app.forum_posts)
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function getForumPosts(client, courseId) {
--   const sql =
--     "SELECT post_id, title, content, created_at " +
--     "FROM app.forum_posts " +
--     "WHERE course_id = " + courseId +
--     " AND is_moderated = false";
--
--   return client.query(sql);
-- }

-- Пример атаки — модерация:
-- courseId: 1 OR 1=1 --
-- Итоговый запрос:
-- ... WHERE course_id = 1 OR 1=1 -- AND is_moderated = false
-- Результат: ВСЕ посты, включая модерированные


-- =====================================================
-- ЧАСТЬ B: БЕЗОПАСНЫЕ ХРАНИМЫЕ ФУНКЦИИ ДЛЯ СХЕМЫ APP
-- =====================================================
-- Создаём функции с параметризованными запросами,
-- которые приложение будет вызывать вместо сборки SQL.

-- =====================================================
-- B.1: Безопасная аутентификация
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_login($1, $2)',
--   [username, passwordHash]
-- );

-- Проверка:
PREPARE test_safe_login(TEXT, TEXT) AS
    SELECT * FROM app.safe_login($1, $2);

-- Корректный ввод:
EXECUTE test_safe_login('student1', 'hash1');
-- Результат: 1 строка (student1)

-- Вредоносный ввод — инъекция НЕ работает:
EXECUTE test_safe_login(''' OR 1=1 --', 'anything');
-- Результат: 0 строк

DEALLOCATE test_safe_login;


-- =====================================================
-- B.2: Безопасный поиск курсов
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_search_courses($1)',
--   [keyword]
-- );

-- Проверка:
PREPARE test_search(TEXT) AS
    SELECT * FROM app.safe_search_courses($1);

-- Корректный ввод:
EXECUTE test_search('Python');
-- Результат: 1 строка (Основы Python, status = published)

-- Вредоносный ввод — инъекция НЕ работает:
EXECUTE test_search(''' OR 1=1 --');
-- Результат: 0 строк (ищет буквально "' OR 1=1 --" в title)

DEALLOCATE test_search;


-- =====================================================
-- B.3: Безопасная выборка зачислений пользователя
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_get_enrollments($1)',
--   [userId]
-- );

-- Проверка:
PREPARE test_enrollments(INTEGER) AS
    SELECT * FROM app.safe_get_enrollments($1);

-- Корректный ввод:
EXECUTE test_enrollments(1);
-- Результат: зачисления пользователя с user_id = 1

-- Вредоносный ввод невозможен: тип INTEGER,
-- строка '1 OR 1=1' вызовет ошибку типизации

DEALLOCATE test_enrollments;


-- =====================================================
-- B.4: Безопасная сортировка курсов (белый список)
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
    -- Белый список разрешённых полей сортировки
    v_field := CASE p_sort_field
        WHEN 'title'      THEN 'title'
        WHEN 'price'      THEN 'price'
        WHEN 'status'     THEN 'status'
        WHEN 'created_at' THEN 'created_at'
        ELSE 'created_at'
    END;

    -- Белый список разрешённых направлений
    v_direction := CASE LOWER(p_sort_direction)
        WHEN 'asc'  THEN 'ASC'
        WHEN 'desc' THEN 'DESC'
        ELSE 'DESC'
    END;

    -- Безопасная подстановка (только значения из белого списка)
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_list_courses($1, $2)',
--   [sortField, sortDirection]
-- );

-- Проверка — корректные значения:
SELECT * FROM app.safe_list_courses('title', 'asc');
SELECT * FROM app.safe_list_courses('price', 'desc');

-- Проверка — вредоносный ввод → подставится значение по умолчанию:
SELECT * FROM app.safe_list_courses('title; DROP TABLE app.users; --', 'asc');
-- Результат: сортировка по created_at DESC (значение по умолчанию)


-- =====================================================
-- B.5: Безопасная фильтрация постов форума
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_get_forum_posts($1, $2)',
--   [courseId, false]
-- );


-- =====================================================
-- B.6: Безопасная отправка работы студентом
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

-- Использование в приложении:
-- const result = await client.query(
--   'SELECT * FROM app.safe_submit_assignment($1, $2, $3)',
--   [assignmentId, userId, content]
-- );


-- =====================================================
-- B.7: Безопасное обновление статуса зачисления
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
    -- Белый список допустимых статусов
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
-- ЧАСТЬ C: ОГРАНИЧЕННАЯ РОЛЬ ПРИЛОЖЕНИЯ ДЛЯ СХЕМЫ APP
-- =====================================================

-- Создаём роль с минимальными правами, через которую
-- приложение подключается к БД

DROP ROLE IF EXISTS web_app_secure;
CREATE ROLE web_app_secure LOGIN PASSWORD 'SecureApp2024!';

-- Доступ к схеме
GRANT USAGE ON SCHEMA app TO web_app_secure;

-- Минимальные права на таблицы (только чтение)
GRANT SELECT ON app.users TO web_app_secure;
GRANT SELECT ON app.courses TO web_app_secure;
GRANT SELECT ON app.lessons TO web_app_secure;
GRANT SELECT ON app.assignments TO web_app_secure;
GRANT SELECT ON app.enrollments TO web_app_secure;
GRANT SELECT ON app.submissions TO web_app_secure;
GRANT SELECT ON app.forum_posts TO web_app_secure;
GRANT SELECT ON app.certificates TO web_app_secure;

-- Ограниченные права на запись (только необходимые операции)
GRANT INSERT ON app.submissions TO web_app_secure;
GRANT UPDATE (status) ON app.enrollments TO web_app_secure;
GRANT INSERT ON app.forum_posts TO web_app_secure;
GRANT UPDATE (content, updated_at) ON app.forum_posts TO web_app_secure;

-- Права на последовательности (для INSERT)
GRANT USAGE ON SEQUENCE app.submissions_submission_id_seq TO web_app_secure;
GRANT USAGE ON SEQUENCE app.forum_posts_post_id_seq TO web_app_secure;

-- Право вызывать безопасные функции
GRANT EXECUTE ON FUNCTION app.safe_login(TEXT, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_search_courses(TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_get_enrollments(INTEGER) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_list_courses(TEXT, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_get_forum_posts(INTEGER, BOOLEAN) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_submit_assignment(INTEGER, INTEGER, TEXT) TO web_app_secure;
GRANT EXECUTE ON FUNCTION app.safe_update_enrollment_status(INTEGER, INTEGER, TEXT) TO web_app_secure;

-- Логирование действий (INSERT в access_logs)
GRANT INSERT ON app.access_logs TO web_app_secure;
GRANT USAGE ON SEQUENCE app.access_logs_log_id_seq TO web_app_secure;


-- =====================================================
-- ЧАСТЬ D: ПРОВЕРКА МАТРИЦЫ ПРАВ web_app_secure
-- =====================================================

SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'web_app_secure'
ORDER BY table_name, privilege_type;

-- Ожидаемый результат: только SELECT на большинство таблиц,
-- INSERT/UPDATE только на submissions, enrollments, forum_posts


-- =====================================================
-- ЧАСТЬ E: СРАВНЕНИЕ — КАК ПРИЛОЖЕНИЕ ДОЛЖНО РАБОТАТЬ
-- =====================================================

-- ┌─────────────────────────────┬──────────────────────────────────────┬──────────────────────────────────────────┐
-- │ Операция                    │ БЫЛО (уязвимо)                       │ СТАЛО (безопасно)                        │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Аутентификация              │ "WHERE username='" + user + "'"      │ SELECT * FROM app.safe_login($1, $2)     │
-- │ (app.users)                 │ Конкатенация строк                   │ Параметризация + хранимая функция        │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Поиск курсов                │ "WHERE title ILIKE '%" + kw + "%'"   │ SELECT * FROM app.safe_search_courses($1)│
-- │ (app.courses)               │ Конкатенация строк                   │ Параметризация + хранимая функция        │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Зачисления пользователя     │ "WHERE user_id = " + userId          │ SELECT * FROM app.safe_get_enrollments($1│
-- │ (app.enrollments)           │ Конкатенация числа                   │ Параметризация (тип INTEGER)             │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Сортировка курсов           │ "ORDER BY " + field + " " + dir      │ SELECT * FROM app.safe_list_courses($1,$2│
-- │ (app.courses)               │ Прямая подстановка идентификатора    │ Белый список (CASE) + format(%I)         │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Посты форума                │ "WHERE course_id = " + id            │ SELECT * FROM app.safe_get_forum_posts($1│
-- │ (app.forum_posts)           │ Конкатенация числа                   │ Параметризация (тип INTEGER)             │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Отправка работы             │ "VALUES(" + aid + "," + uid + "..."  │ SELECT * FROM app.safe_submit_assignment(│
-- │ (app.submissions)           │ Конкатенация значений                │ Параметризация (3 параметра)             │
-- ├─────────────────────────────┼──────────────────────────────────────┼──────────────────────────────────────────┤
-- │ Обновление статуса          │ "SET status='" + status + "'"        │ app.safe_update_enrollment_status($1,$2, │
-- │ (app.enrollments)           │ Конкатенация строки                  │ Белый список статусов + параметризация   │
-- └─────────────────────────────┴──────────────────────────────────────┴──────────────────────────────────────────┘

-- Дополнительная защита уже реализована в предыдущих практиках:
-- • RLS-политики на всех таблицах (практики 3-6)
-- • RBAC-роли с наследованием (app_guest → app_student → ... → app_admin)
-- • Аудит через app.access_logs

-- Итого: МНОГОУРОВНЕВАЯ ЗАЩИТА
-- 1 уровень: Параметризованные запросы / белые списки (код приложения)
-- 2 уровень: Хранимые функции с SECURITY DEFINER (уровень БД)
-- 3 уровень: Ограниченная роль web_app_secure (минимальные привилегии)
-- 4 уровень: RLS-политики (строковая безопасность, из практик 3-6)
-- 5 уровень: RBAC (ролевой доступ, из практик 3-6)


-- =====================================================
-- КОНЕЦ ДОПОЛНЕНИЯ К ПРАКТИКЕ 9
-- =====================================================
