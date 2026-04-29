смотри какая у меня задача мне требуеться доработать db в postgresql вот исходный код 
-- Создание базы данных
CREATE DATABASE online_learning_v2;

-- Схема приложения
CREATE SCHEMA app;

-- Таблицы для RBAC
-- Пользователи
CREATE TABLE app.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Роли
CREATE TABLE app.roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    parent_role_id INTEGER REFERENCES app.roles (role_id)
);

-- Разрешения
CREATE TABLE app.permissions (
    permission_id SERIAL PRIMARY KEY,
    permission_name VARCHAR(100) UNIQUE NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    operation VARCHAR(20) NOT NULL -- create, read, update, delete
);

-- Связь пользователей с ролями
CREATE TABLE app.user_roles (
    user_id INTEGER REFERENCES app.users (user_id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES app.roles (role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER REFERENCES app.users (user_id),
    PRIMARY KEY (user_id, role_id) -- для уникальность пары (user_id, role_id), чтобы 1 пользователь не мог имень несколько ролей.
);

-- Связь ролей с разрешениями
CREATE TABLE app.role_permissions (
    role_id INTEGER REFERENCES app.roles (role_id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES app.permissions (permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Сессии пользователей
CREATE TABLE app.sessions (
    session_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app.users (user_id),
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблицы образовательной платформы
-- Курсы
CREATE TABLE app.courses (
    course_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'draft' CHECK (
        status IN (
            'draft',
            'published',
            'archived'
        )
    ),
    created_by INTEGER REFERENCES app.users (user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP
);

-- Зачисление студентов на курсы (оплата, доступ)
CREATE TABLE app.enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app.users (user_id),
    course_id INTEGER REFERENCES app.courses (course_id),
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (
        status IN (
            'active',
            'completed',
            'dropped'
        )
    ),
    UNIQUE (user_id, course_id)
);

-- Преподавательский состав курса (авторы, преподаватели, кураторы)
CREATE TABLE app.course_staff (
    course_id INTEGER REFERENCES app.courses (course_id),
    user_id INTEGER REFERENCES app.users (user_id),
    role_type VARCHAR(20) NOT NULL CHECK (
        role_type IN (
            'author',
            'teacher',
            'curator'
        )
    ),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (course_id, user_id, role_type)
);

-- Уроки
CREATE TABLE app.lessons (
    lesson_id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES app.courses (course_id),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    order_number INTEGER NOT NULL,
    type VARCHAR(20) DEFAULT 'video' CHECK (
        type IN (
            'video',
            'text',
            'quiz',
            'assignment'
        )
    )
);

-- Задания (домашние работы)
CREATE TABLE app.assignments (
    assignment_id SERIAL PRIMARY KEY,
    lesson_id INTEGER REFERENCES app.lessons (lesson_id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date TIMESTAMP
);

-- Сданные работы студентов
CREATE TABLE app.submissions (
    submission_id SERIAL PRIMARY KEY,
    assignment_id INTEGER REFERENCES app.assignments (assignment_id),
    user_id INTEGER REFERENCES app.users (user_id),
    content TEXT,
    grade INTEGER CHECK (grade BETWEEN 0 AND 100),
    feedback TEXT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    graded_at TIMESTAMP,
    graded_by INTEGER REFERENCES app.users (user_id)
);

-- Сообщения форума
CREATE TABLE app.forum_posts (
    post_id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES app.courses (course_id),
    user_id INTEGER REFERENCES app.users (user_id),
    parent_post_id INTEGER REFERENCES app.forum_posts (post_id),
    title VARCHAR(200),
    content TEXT NOT NULL,
    is_moderated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Сертификаты
CREATE TABLE app.certificates (
    certificate_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app.users (user_id),
    course_id INTEGER REFERENCES app.courses (course_id),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    certificate_url VARCHAR(255)
);

-- Логи доступа (для аудита)
CREATE TABLE app.access_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app.users (user_id),
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id INTEGER,
    ip_address INET,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Добавление информации в пользователей
INSERT INTO
    app.users (
        username,
        email,
        password_hash,
        full_name
    )
VALUES (
        'student1',
        'student1@edu.com',
        'hash1',
        'Иван Петров'
    ),
    (
        'student2',
        'student2@edu.com',
        'hash2',
        'Мария Иванова'
    ),
    (
        'teacher1',
        'teacher1@edu.com',
        'hash3',
        'Алексей Смирнов'
    ),
    (
        'author1',
        'author1@edu.com',
        'hash4',
        'Елена Кузнецова'
    ),
    (
        'curator1',
        'curator1@edu.com',
        'hash5',
        'Ольга Васильева'
    ),
    (
        'moderator1',
        'moderator1@edu.com',
        'hash6',
        'Дмитрий Соколов'
    ),
    (
        'analyst1',
        'analyst1@edu.com',
        'hash7',
        'Анна Попова'
    ),
    (
        'admin1',
        'admin1@edu.com',
        'hash8',
        'Максим Орлов'
    );

-- Курсы
INSERT INTO
    app.courses (
        title,
        description,
        price,
        status,
        created_by
    )
VALUES (
        'Основы Python',
        'Введение в программирование',
        5000,
        'published',
        3
    ),
    (
        'Веб-разработка',
        'HTML/CSS/JS',
        7000,
        'published',
        4
    ),
    (
        'Базы данных',
        'SQL и NoSQL',
        6000,
        'draft',
        3
    ),
    (
        'Java-разработчик',
        'Java-junior',
        8000,
        'archived',
        5
    );

-- Зачисления
INSERT INTO
    app.enrollments (user_id, course_id)
VALUES (1, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 1);

-- Преподавательский состав
INSERT INTO
    app.course_staff (course_id, user_id, role_type)
VALUES (1, 3, 'teacher'),
    (1, 5, 'curator'),
    (2, 4, 'author'),
    (2, 3, 'teacher');

-- Уроки
INSERT INTO
    app.lessons (
        course_id,
        title,
        order_number
    )
VALUES (1, 'Установка Python', 1),
    (
        1,
        'Переменные и типы данных',
        2
    ),
    (2, 'HTML основы', 1),
    (3, 'Java-разработчик', 2);

-- Задания
INSERT INTO
    app.assignments (lesson_id, title, description)
VALUES (
        1,
        'Установка Python',
        'Напишите инструкцию по установке'
    ),
    (
        2,
        'Практика с переменными',
        'Решите 5 задач'
    ),
    (
        3,
        'Основы Java',
        'написать рабочий софт'
    );

-- Сдачи заданий
INSERT INTO
    app.submissions (
        assignment_id,
        user_id,
        content
    )
VALUES (
        1,
        1,
        'Установил Python 3.9...'
    ),
    (2, 1, 'Решения...'),
    (3, 2, 'Написание...');

-- Проверка целостность данных с помощью SELECT-запросов
SELECT * FROM app.users;

SELECT * FROM app.courses;

SELECT * FROM app.enrollments;

SELECT * FROM app.course_staff;

SELECT * FROM app.lessons;

SELECT * FROM app.assignments;

SELECT * FROM app.submissions;



-- Настройка различных методов аутентификации

-- 1 Проверитим текущий метод шифрования паролей
SHOW password_encryption;
-- как я понимаю по умолчанию scram-sha-256
-- 2 Принудительно обновить пароли существующих пользователей, чтобы гарантировать хеширование по алгоритму SCRAM-SHA-256, но раз я ранее создавал, то у нас хеширование должно быть SCRAM-SHA-256.
ALTER USER student1   WITH PASSWORD 'StudentPass123';
ALTER USER student2   WITH PASSWORD 'StudentPass456';
ALTER USER teacher1   WITH PASSWORD 'TeacherPass123';
ALTER USER author1    WITH PASSWORD 'AuthorPass123';
ALTER USER curator1   WITH PASSWORD 'CuratorPass123';
ALTER USER moderator1 WITH PASSWORD 'ModeratorPass123';
ALTER USER analyst1   WITH PASSWORD 'AnalystPass123';
ALTER USER admin1     WITH PASSWORD 'AdminPass777';

-- 3 Создать дополнительных тестовых пользователей для демонстрации, различных методов хеширования (для сравнения md5 и scram) потестировать.
SET password_encryption = 'md5';
CREATE USER legacy_md5_user WITH PASSWORD 'LegacyPass123';
-- переключение обратно
SET password_encryption = 'scram-sha-256';
CREATE USER modern_scram_user WITH PASSWORD 'ModernPass123';

-- Проверить сохранённые хеши
SELECT usename,
    CASE
        WHEN passwd LIKE 'md5%' THEN 'md5'
        WHEN passwd LIKE 'SCRAM-SHA-256%' THEN 'scram-sha-256'
        ELSE 'unknown'
    END AS encryption_method
FROM pg_shadow
WHERE usename IN ('student1', 'teacher1', 'admin1','legacy_md5_user', 'modern_scram_user');

-- 4 Включить расширенное логирование подключений и действий
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'ddl';   -- логировать DDL-операции, то есть записываю информацию журнал (лог-файл)
ALTER SYSTEM SET log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '; -- это у нас формат строк в файле. Временная метка, Идентификатор процесса, Имя пользователя БД, Имя базы данных, к которой подключён пользователь, Имя приложения (задаётся клиентом, например psql, DBeaver), IP-адрес клиента или хост
SELECT pg_reload_conf();

-- Проверить, что настройки применились
SHOW log_connections;
SHOW log_disconnections;
SHOW log_statement;

-- Для просмотра логов можно использовать встроенное представление pg_stat_activity
SELECT pid, usename, application_name, client_addr, state, query
FROM pg_stat_activity
WHERE datname = current_database()
AND state = 'active';

-- Активные сессии для пользователей онлайн-школы, но сейчас нету поэтому пустота
SELECT 
    pid AS "PID",
    usename AS "Пользователь",
    application_name AS "Приложение",
    client_addr AS "IP-адрес",
    state AS "Состояние",
    query AS "Текущий запрос"
FROM pg_stat_activity
WHERE datname = 'online_learning_v2'
AND usename IN ('student1', 'student2', 'teacher1', 'author1', 'curator1', 'moderator1', 'analyst1', 'admin1')
AND state = 'active'
ORDER BY usename;

-- Все активные соединения
SELECT * FROM pg_stat_activity WHERE datname = 'online_learning_v2';


-- РЕАЛИЗАЦИЯ RBAC-МОДЕЛИ
-- Создаём роли
-- Роль Гость
CREATE ROLE app_guest;
-- Роль студента
CREATE ROLE app_student;
-- Роль куратора
CREATE ROLE app_curator;
-- Роль учителя
CREATE ROLE app_teacher;
-- Роль автора
CREATE ROLE app_author;
-- Роль модератора
CREATE ROLE app_moderator;
-- Роль аналитика
CREATE ROLE app_analyst;
-- Роль админа
CREATE ROLE app_admin;

-- настройка иерархии через наследование (RBAC₁)
GRANT app_guest TO app_student;

GRANT app_student TO app_curator;

GRANT app_curator TO app_teacher;

GRANT app_teacher TO app_author;
-- Модератор, аналитик и админ не наследуют, чтобы не дать лишних прав
GRANT app_guest TO app_analyst;
-- аналитик видит только публичное (но мы дадим ему SELECT на users отдельно)


-- Настроить RLS

-- Предоставление привилегий на схему и таблицы
-- Схема: доступ для всех ролей, но с разными правами
-- Доступ к схеме
GRANT USAGE ON SCHEMA app TO app_guest,
app_student,
app_curator,
app_teacher,
app_author,
app_moderator,
app_analyst,
app_admin;

-- Настройка привилегий для роли GUEST
-- Гость: только чтение публичных курсов
GRANT
SELECT (
        course_id, title, description, price, status, created_at
    ) ON app.courses TO app_guest;
-- Публичные уроки (через RLS ограничим только опубликованные курсы)
GRANT
SELECT (
        lesson_id, course_id, title, order_number
    ) ON app.lessons TO app_guest;
-- Просмотр форума (все посты)
GRANT SELECT ON app.forum_posts TO app_guest;

-- Роль STUDENT (наследует GUEST)
-- Чтение информации о себе
GRANT
SELECT (
        user_id, username, full_name, email, is_active
    ) ON app.users TO app_student;

GRANT UPDATE (full_name, email) ON app.users TO app_student;

-- courses: SELECT только где зачислен (RLS)
GRANT SELECT ON app.courses TO app_student;

-- lessons: SELECT свои курсы (RLS)
GRANT SELECT ON app.lessons TO app_student;

-- assignments: SELECT свои данные (т.е. задания в своих курсах) – через RLS
GRANT SELECT ON app.assignments TO app_student;

-- submissions: SELECT свои курсы (через RLS покажу только свои submission)
GRANT SELECT ON app.submissions TO app_student;
-- submissions: CREATE (свои сдачи)
GRANT INSERT ON app.submissions TO app_student;

GRANT USAGE ON SEQUENCE app.submissions_submission_id_seq TO app_student;
-- submissions: UPDATE/INSERT до проверки (через RLS ограничим)
GRANT UPDATE (content) ON app.submissions TO app_student;

-- forum_posts: SELECT, INSERT (в свои курсы), UPDATE/DELETE свои посты
GRANT SELECT, INSERT ON app.forum_posts TO app_student;

GRANT UPDATE, DELETE ON app.forum_posts TO app_student;

GRANT USAGE ON SEQUENCE app.forum_posts_post_id_seq TO app_student;

-- certificates: SELECT свои данные
GRANT SELECT ON app.certificates TO app_student;

-- Роль CURATOR (наследует STUDENT)
-- Дополнительно: может просматривать и оценивать работы студентов в своих курсах
-- Наследует student, поэтому дополнительные права:
-- courses: SELECT где назначен (RLS)
-- lessons: SELECT свои курсы (уже есть)
-- assignments: SELECT свои курсы (уже есть)
-- submissions: SELECT свои курсы (уже есть)
-- course_staff: SELECT свои курсы
GRANT SELECT ON app.course_staff TO app_curator;
-- (только SELECT нет INSERT/UPDATE/DELETE)

-- Роль TEACHER (наследует CURATOR)
-- Наследует curator, добавляем:
-- courses: UPDATE свои уроки (но курсы teacher не обновляет, только уроки – это через lessons)
-- lessons: INSERT/UPDATE в своих курсах
GRANT INSERT, UPDATE, DELETE ON app.lessons TO app_teacher;

GRANT USAGE ON SEQUENCE app.lessons_lesson_id_seq TO app_teacher;

-- assignments: CREATE, UPDATE, DELETE в своих курсах
GRANT INSERT, UPDATE, DELETE ON app.assignments TO app_teacher;

GRANT USAGE ON SEQUENCE app.assignments_assignment_id_seq TO app_teacher;

-- Роль AUTHOR (наследует TEACHER)
-- Наследует teacher, добавляем:
-- courses: INSERT, UPDATE (свои данные), DELETE (свои данные)
GRANT INSERT, UPDATE, DELETE ON app.courses TO app_author;

GRANT USAGE ON SEQUENCE app.courses_course_id_seq TO app_author;

-- course_staff: SELECT, INSERT, UPDATE, DELETE (свои курсы)
GRANT
SELECT, INSERT,
UPDATE, DELETE ON app.course_staff TO app_author;

-- Привилегии для MODERATOR (не наследует)
-- Полный SELECT на все таблицы (для модерации)
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_moderator;

-- forum_posts: UPDATE/DELETE любые посты
GRANT UPDATE, DELETE ON app.forum_posts TO app_moderator;

-- users: UPDATE is_active (блокировка)
GRANT UPDATE (is_active) ON app.users TO app_moderator;

-- Привилегии для ANALYST (только чтение users)
GRANT SELECT ON app.users TO app_analyst;
-- Доступа к другим таблицам нет

-- Привилегии для ADMIN
-- Имеет полныое разрешение на все
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO app_admin;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO app_admin;

GRANT CREATE ON SCHEMA app TO app_admin;

-- Создание пользователей и назначение ролей
-- Создаём пользователей с паролями

CREATE USER student1 WITH PASSWORD 'StudentPass123';

CREATE USER student2 WITH PASSWORD 'StudentPass456';

CREATE USER teacher1 WITH PASSWORD 'TeacherPass123';

CREATE USER author1 WITH PASSWORD 'AuthorPass123';

CREATE USER curator1 WITH PASSWORD 'CuratorPass123';

CREATE USER moderator1 WITH PASSWORD 'ModeratorPass123';

CREATE USER analyst1 WITH PASSWORD 'AnalystPass123';

CREATE USER admin1 WITH PASSWORD 'AdminPass777';

GRANT app_student TO student1, student2;

GRANT app_teacher TO teacher1;

GRANT app_author TO author1;

GRANT app_curator TO curator1;

GRANT app_moderator TO moderator1;

GRANT app_analyst TO analyst1;

GRANT app_admin TO admin1;

-- Просмотр прав ролей на таблицы
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE
    grantee IN (
        'app_guest',
        'app_student',
        'app_curator',
        'app_teacher',
        'app_author',
        'app_moderator',
        'app_analyst',
        'app_admin'
    )
ORDER BY
    grantee,
    table_name,
    privilege_type;

-- Проверка наследования ролей
SELECT r.rolname AS role, m.rolname AS member_of
FROM
    pg_auth_members am
    JOIN pg_roles r ON r.oid = am.member
    JOIN pg_roles m ON m.oid = am.roleid
ORDER BY 1, 2;

-- Вспомогательная функция: получить user_id из таблицы users по текущей роли
CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT user_id FROM app.users WHERE username = current_user;
$$;

-- ROW-LEVEL SECURITY (RLS) - ДОПОЛНИТЕЛЬНАЯ ЗАЩИТА
-- та самая реализация RLS
-- Включаем RLS
ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.courses ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.lessons ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.assignments ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.submissions ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.forum_posts ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.certificates ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.course_staff ENABLE ROW LEVEL SECURITY;

-- ПОЛИТИКИ ДЛЯ TABLES
-- users
-- Студент, куратор, учитель, автор, модератор видят только свои данные
CREATE POLICY users_self_select ON app.users
    FOR SELECT TO app_student, app_curator, app_teacher, app_author, app_moderator
    USING (username = current_user);

-- Аналитик и админ видят всех
CREATE POLICY users_analyst_admin_select ON app.users FOR
SELECT TO app_analyst, app_admin USING (true);

-- Обновление своих данных (student, curator, teacher, author, moderator)
CREATE POLICY users_self_update ON app.users
    FOR UPDATE TO app_student, app_curator, app_teacher, app_author, app_moderator
    USING (username = current_user)
    WITH CHECK (username = current_user);

-- Модератор может обновлять is_active (дополнительная политика)
CREATE POLICY users_moderator_update_active ON app.users
    FOR UPDATE TO app_moderator USING (true) WITH CHECK (true);

-- Админ может всё (политика ALL)
CREATE POLICY users_admin_all ON app.users FOR ALL TO app_admin USING (true);

-- courses
-- Гость: только опубликованные курсы
CREATE POLICY courses_guest_select ON app.courses FOR
SELECT TO app_guest USING (status = 'published');

-- Студент: курсы, на которые зачислен (активные зачисления)
CREATE POLICY courses_student_select ON app.courses FOR
SELECT TO app_student USING (
        EXISTS (
            SELECT 1
            FROM app.enrollments e
            WHERE
                e.user_id = app.current_user_id ()
                AND e.course_id = courses.course_id
                AND e.status = 'active'
        )
    );

-- Куратор: курсы, где назначен в course_staff (любая роль)
CREATE POLICY courses_curator_select ON app.courses FOR
SELECT TO app_curator USING (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs
            WHERE
                cs.user_id = app.current_user_id ()
                AND cs.course_id = courses.course_id
        )
    );

-- Учитель: курсы, где преподает (role_type = 'teacher')
CREATE POLICY courses_teacher_select ON app.courses FOR
SELECT TO app_teacher USING (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs
            WHERE
                cs.user_id = app.current_user_id ()
                AND cs.course_id = courses.course_id
                AND cs.role_type = 'teacher'
        )
    );

-- Автор: свои курсы (где он автор)
CREATE POLICY courses_author_select ON app.courses FOR
SELECT TO app_author USING (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs
            WHERE
                cs.user_id = app.current_user_id ()
                AND cs.course_id = courses.course_id
                AND cs.role_type = 'author'
        )
    );

-- Автор: может INSERT (создавать новые курсы) – политика не нужна, так как GRANT уже разрешает, а RLS для INSERT проверяет WITH CHECK, можно добавить проверку, что created_by = текущий пользователь
CREATE POLICY courses_author_insert ON app.courses FOR INSERT TO app_author
WITH
    CHECK (
        created_by = app.current_user_id ()
    );

-- Автор: может UPDATE/DELETE только свои курсы
CREATE POLICY courses_author_update_delete ON app.courses
FOR UPDATE
    TO app_author USING (
        created_by = app.current_user_id ()
    );
-- для DELETE аналогично (но в PostgreSQL политика FOR ALL покрывает)
CREATE POLICY courses_author_delete ON app.courses FOR DELETE TO app_author USING (
    created_by = app.current_user_id ()
);

-- Модератор и админ видят всё
CREATE POLICY courses_moderator_admin_select ON app.courses FOR
SELECT TO app_moderator, app_admin USING (true);

-- Админ может всё
CREATE POLICY courses_admin_all ON app.courses FOR ALL TO app_admin USING (true);

-- lessons
-- Гость: только уроки из опубликованных курсов
CREATE POLICY lessons_guest_select ON app.lessons FOR
SELECT TO app_guest USING (
        EXISTS (
            SELECT 1
            FROM app.courses c
            WHERE
                c.course_id = lessons.course_id
                AND c.status = 'published'
        )
    );

-- Студент: уроки из курсов, на которые зачислен
CREATE POLICY lessons_student_select ON app.lessons FOR
SELECT TO app_student USING (
        EXISTS (
            SELECT 1
            FROM app.enrollments e
            WHERE
                e.user_id = app.current_user_id ()
                AND e.course_id = lessons.course_id
                AND e.status = 'active'
        )
    );

-- Куратор, учитель, автор: уроки из своих курсов (через course_staff)
CREATE POLICY lessons_staff_select ON app.lessons FOR
SELECT
    TO app_curator,
    app_teacher,
    app_author USING (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs
            WHERE
                cs.user_id = app.current_user_id ()
                AND cs.course_id = lessons.course_id
        )
    );

-- Учитель и автор: могут управлять уроками в своих курсах
CREATE POLICY lessons_teacher_author_manage ON app.lessons FOR ALL TO app_teacher,
app_author USING (
    EXISTS (
        SELECT 1
        FROM app.course_staff cs
        WHERE
            cs.user_id = app.current_user_id ()
            AND cs.course_id = lessons.course_id
            AND cs.role_type IN ('teacher', 'author')
    )
);

-- Модератор и админ видят всё
CREATE POLICY lessons_moderator_admin_select ON app.lessons FOR
SELECT TO app_moderator, app_admin USING (true);

CREATE POLICY lessons_admin_all ON app.lessons FOR ALL TO app_admin USING (true);

-- assignments
-- Студент: видит задания из своих курсов
CREATE POLICY assignments_student_select ON app.assignments FOR
SELECT TO app_student USING (
        EXISTS (
            SELECT 1
            FROM app.lessons l
                JOIN app.enrollments e ON e.course_id = l.course_id
            WHERE
                l.lesson_id = assignments.lesson_id
                AND e.user_id = app.current_user_id ()
                AND e.status = 'active'
        )
    );

-- Куратор, учитель, автор: задания из своих курсов
CREATE POLICY assignments_staff_select ON app.assignments FOR
SELECT
    TO app_curator,
    app_teacher,
    app_author USING (
        EXISTS (
            SELECT 1
            FROM app.lessons l
                JOIN app.course_staff cs ON cs.course_id = l.course_id
            WHERE
                l.lesson_id = assignments.lesson_id
                AND cs.user_id = app.current_user_id ()
        )
    );

-- Учитель и автор: могут создавать, обновлять, удалять задания в своих курсах
CREATE POLICY assignments_teacher_author_manage ON app.assignments FOR ALL TO app_teacher,
app_author USING (
    EXISTS (
        SELECT 1
        FROM app.lessons l
            JOIN app.course_staff cs ON cs.course_id = l.course_id
        WHERE
            l.lesson_id = assignments.lesson_id
            AND cs.user_id = app.current_user_id ()
            AND cs.role_type IN ('teacher', 'author')
    )
);

-- Модератор и админ видят всё
CREATE POLICY assignments_moderator_admin_select ON app.assignments FOR
SELECT TO app_moderator, app_admin USING (true);

CREATE POLICY assignments_admin_all ON app.assignments FOR ALL TO app_admin USING (true);

-- submissions
-- Студент: видит только свои сдачи
CREATE POLICY submissions_student_select ON app.submissions FOR
SELECT TO app_student USING (
        user_id = app.current_user_id ()
    );

-- Куратор, учитель, автор: видят сдачи в своих курсах
CREATE POLICY submissions_staff_select ON app.submissions FOR
SELECT
    TO app_curator,
    app_teacher,
    app_author USING (
        EXISTS (
            SELECT 1
            FROM app.assignments a
                JOIN app.lessons l ON l.lesson_id = a.lesson_id
                JOIN app.course_staff cs ON cs.course_id = l.course_id
            WHERE
                a.assignment_id = submissions.assignment_id
                AND cs.user_id = app.current_user_id ()
        )
    );

-- Студент: может создавать сдачи (только если задание из его курса и не оценено)
CREATE POLICY submissions_student_insert ON app.submissions FOR INSERT TO app_student
WITH
    CHECK (
        user_id = app.current_user_id ()
        AND EXISTS (
            SELECT 1
            FROM app.assignments a
                JOIN app.lessons l ON l.lesson_id = a.lesson_id
                JOIN app.enrollments e ON e.course_id = l.course_id
            WHERE
                a.assignment_id = submissions.assignment_id
                AND e.user_id = app.current_user_id ()
                AND e.status = 'active'
        )
        AND graded_at IS NULL
    );

-- Студент: может обновлять свою сдачу до проверки (graded_at IS NULL)
CREATE POLICY submissions_student_update ON app.submissions
FOR UPDATE
    TO app_student USING (
        user_id = app.current_user_id ()
        AND graded_at IS NULL
    )
WITH
    CHECK (
        user_id = app.current_user_id ()
        AND graded_at IS NULL
    );

-- Модератор и админ видят всё
CREATE POLICY submissions_moderator_admin_select ON app.submissions FOR
SELECT TO app_moderator, app_admin USING (true);

CREATE POLICY submissions_admin_all ON app.submissions FOR ALL TO app_admin USING (true);

-- forum_posts
-- Все роли (кроме analyst) видят все посты
CREATE POLICY forum_posts_select_all ON app.forum_posts FOR
SELECT
    TO app_guest,
    app_student,
    app_curator,
    app_teacher,
    app_author,
    app_moderator,
    app_admin USING (true);

-- Вставка: все роли, кроме guest и analyst
CREATE POLICY forum_posts_insert_student ON app.forum_posts FOR INSERT TO app_student
WITH
    CHECK (
        EXISTS (
            SELECT 1
            FROM app.enrollments e
            WHERE
                e.user_id = app.current_user_id ()
                AND e.course_id = forum_posts.course_id
        )
    );

CREATE POLICY forum_posts_insert_teacher_author_curator ON app.forum_posts FOR INSERT TO app_curator,
app_teacher,
app_author
WITH
    CHECK (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs
            WHERE
                cs.user_id = app.current_user_id ()
                AND cs.course_id = forum_posts.course_id
        )
    );

CREATE POLICY forum_posts_insert_moderator_admin ON app.forum_posts FOR INSERT TO app_moderator,
app_admin
WITH
    CHECK (true);

-- UPDATE/DELETE: свои посты для student, curator, teacher, author
CREATE POLICY forum_posts_self_update_delete ON app.forum_posts
FOR UPDATE
    TO app_student,
    app_curator,
    app_teacher,
    app_author USING (
        user_id = app.current_user_id ()
    );
-- отдельно для DELETE
CREATE POLICY forum_posts_self_delete ON app.forum_posts FOR DELETE TO app_student,
app_curator,
app_teacher,
app_author USING (
    user_id = app.current_user_id ()
);

-- Модератор: может удалять/обновлять любые посты
CREATE POLICY forum_posts_moderator_all ON app.forum_posts FOR ALL TO app_moderator USING (true);

-- Админ: всё
CREATE POLICY forum_posts_admin_all ON app.forum_posts FOR ALL TO app_admin USING (true);

-- certificates
-- Студент, куратор, учитель, автор: видят свои сертификаты
CREATE POLICY certificates_self_select ON app.certificates FOR
SELECT
    TO app_student,
    app_curator,
    app_teacher,
    app_author USING (
        user_id = app.current_user_id ()
    );

-- Модератор и админ видят все
CREATE POLICY certificates_moderator_admin_select ON app.certificates FOR
SELECT TO app_moderator, app_admin USING (true);

-- Только админ может INSERT/UPDATE/DELETE
CREATE POLICY certificates_admin_all ON app.certificates FOR ALL TO app_admin USING (true);

-- course_staff
-- Куратор, учитель, автор: видят состав только своих курсов
CREATE POLICY course_staff_self_select ON app.course_staff FOR
SELECT
    TO app_curator,
    app_teacher,
    app_author USING (
        EXISTS (
            SELECT 1
            FROM app.course_staff cs2
            WHERE
                cs2.user_id = app.current_user_id ()
                AND cs2.course_id = course_staff.course_id
        )
    );

-- Автор: может управлять составом своих курсов
CREATE POLICY course_staff_author_manage ON app.course_staff FOR ALL TO app_author USING (
    EXISTS (
        SELECT 1
        FROM app.course_staff cs2
        WHERE
            cs2.user_id = app.current_user_id ()
            AND cs2.course_id = course_staff.course_id
            AND cs2.role_type = 'author'
    )
);

-- Модератор и админ видят всё
CREATE POLICY course_staff_moderator_admin_select ON app.course_staff FOR
SELECT TO app_moderator, app_admin USING (true);

CREATE POLICY course_staff_admin_all ON app.course_staff FOR ALL TO app_admin USING (true);

-- что еще можно использовать это отозывать роли, сброс и перевыдачи привилегий (на примере роли app_curator)
-- Временно отзываем все права у куратора на таблицу submissions
-- REVOKE ALL PRIVILEGES ON TABLE app.submissions FROM app_curator;
-- -- Проверяем, что права исчезли
-- SELECT has_table_privilege('app_curator', 'app.submissions', 'SELECT') AS curator_can_select;
-- Восстанавливаем права, используя подход через контейнер
-- GRANT SELECT, UPDATE ON TABLE app.submissions TO app_curator;  -- как было изначально

-- Настройка DEFAULT PRIVILEGES для автоматического предоставления прав, на новые объекты, создаваемые в схеме app администратором или автором курса.
-- Для таблиц, создаваемых администратором (app_admin):
-- ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA app GRANT SELECT ON TABLES TO app_public_reader, app_course_content_reader; это пример
-- у меня реализованно наследование прав


-- =====================================================
-- ПРАКТИКА 9: Анализ уязвимого к SQL-инъекциям кода
-- приложения и его исправление
-- =====================================================
-- Предметная область: наши таблицы app.users, app.courses и т.д.
-- + лабораторный стенд injection_lab для безопасных экспериментов
-- =====================================================


-- =====================================================
-- ЧАСТЬ 1: ПОДГОТОВКА ЛАБОРАТОРНОГО СТЕНДА
-- =====================================================

-- Задание 1.1: Создание схемы и тестовых данных
-- Создаём отдельную схему, чтобы безопасно моделировать инъекции

CREATE SCHEMA IF NOT EXISTS injection_lab;

DROP TABLE IF EXISTS injection_lab.tasks CASCADE;
DROP TABLE IF EXISTS injection_lab.users CASCADE;

CREATE TABLE injection_lab.users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_plain TEXT NOT NULL
);

CREATE TABLE injection_lab.tasks (
    task_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'new',
    priority TEXT NOT NULL DEFAULT 'medium',
    assignee_username TEXT NOT NULL REFERENCES injection_lab.users(username),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO injection_lab.users (username, full_name, role_name, email, password_plain) VALUES
('alice', 'Alice Ivanova',   'employee', 'alice@corp.local', 'alice123'),
('bob',   'Bob Petrov',      'manager',  'bob@corp.local',   'bob123'),
('carol', 'Carol Sidorova',  'admin',    'carol@corp.local',  'carol123');

INSERT INTO injection_lab.tasks (title, description, status, priority, assignee_username) VALUES
('Подготовить отчёт',       'Собрать метрики по проекту',       'in_progress', 'high',     'alice'),
('Проверить права доступа', 'Аудит ролей PostgreSQL',           'new',         'critical', 'bob'),
('Обновить регламент',      'Документация по реагированию',     'done',        'medium',   'carol'),
('Закрыть инцидент',        'Проверить журналы событий',        'new',         'high',     'alice');

-- Проверка: users = 3, tasks = 4
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM injection_lab.users
UNION ALL
SELECT 'tasks', COUNT(*) FROM injection_lab.tasks;


-- =====================================================
-- ЧАСТЬ 2: АНАЛИЗ УЯЗВИМЫХ ФРАГМЕНТОВ КОДА
-- =====================================================

-- =====================================================
-- Задание 2.1: Уязвимая аутентификация
-- =====================================================

-- УЯЗВИМЫЙ КОД (JavaScript / Node.js + pg):
--
-- async function login(client, username, password) {
--   const sql =
--     "SELECT user_id, username, role_name " +
--     "FROM injection_lab.users " +
--     "WHERE username = '" + username + "' " +
--     "AND password_plain = '" + password + "'";
--   return client.query(sql);
-- }

-- ПОЧЕМУ УЯЗВИМ:
-- username и password подставляются в SQL через конкатенацию строк
-- без экранировки. Злоумышленник может внедрить произвольный SQL-код.

-- Пример вредоносного ввода:
-- username: ' OR 1=1 --
-- password: anything

-- Итоговый запрос после подстановки:
-- SELECT user_id, username, role_name
-- FROM injection_lab.users
-- WHERE username = '' OR 1=1 --' AND password_plain = 'anything'

-- Разбор:
-- 1) username = '' — ложно
-- 2) OR 1=1 — всегда истинно → всё WHERE истинно
-- 3) -- комментирует проверку пароля
-- 4) Результат: возвращаются ВСЕ пользователи — обход аутентификации

-- Демонстрация — нормальный запрос:
SELECT user_id, username, role_name
FROM injection_lab.users
WHERE username = 'alice' AND password_plain = 'alice123';
-- Результат: 1 строка (alice)

-- Демонстрация — атакованный запрос:
SELECT user_id, username, role_name
FROM injection_lab.users
WHERE username = '' OR 1=1 --' AND password_plain = 'anything';
-- Результат: ВСЕ 3 строки — обход аутентификации!

-- Злоумышленник может получить:
-- • user_id, username, role_name ВСЕХ пользователей
-- • Авторизоваться как первый пользователь (возможно admin)
-- • Через UNION извлечь email и пароли


-- =====================================================
-- Задание 2.2: Уязвимый поиск задач
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function findTasksByStatus(client, status) {
--   const sql =
--     "SELECT task_id, title, status, priority " +
--     "FROM injection_lab.tasks " +
--     "WHERE status = '" + status + "'";
--   return client.query(sql);
-- }

-- Пример инъекции (все задачи):
-- status: ' OR 1=1 --

-- Итоговый запрос:
-- SELECT task_id, title, status, priority
-- FROM injection_lab.tasks
-- WHERE status = '' OR 1=1 --'

-- Как работает --:
-- Двойной дефис — однострочный комментарий в SQL.
-- Всё после -- игнорируется, включая закрывающую кавычку.

-- Демонстрация — нормальный запрос:
SELECT task_id, title, status, priority
FROM injection_lab.tasks
WHERE status = 'new';
-- Результат: 2 строки (задачи со статусом new)

-- Демонстрация — атакованный запрос:
SELECT task_id, title, status, priority
FROM injection_lab.tasks
WHERE status = '' OR 1=1 --';
-- Результат: ВСЕ 4 строки — утечка всех задач!

-- Сравнение:
-- Нормальный: 2 задачи (new)
-- Атакованный: 4 задачи (все, включая in_progress и done)


-- =====================================================
-- Задание 2.3: Уязвимая сортировка
-- =====================================================

-- УЯЗВИМЫЙ КОД:
--
-- async function listTasks(client, sortField, sortDirection) {
--   const sql =
--     "SELECT task_id, title, priority, created_at " +
--     "FROM injection_lab.tasks " +
--     "ORDER BY " + sortField + " " + sortDirection;
--   return client.query(sql);
-- }

-- 1) Почему параметризация неприменима к имени столбца:
--    Параметры ($1, $2) подставляются как ЗНАЧЕНИЯ (литералы).
--    Имя столбца — идентификатор SQL. ORDER BY $1 не будет
--    работать как сортировка по столбцу.

-- 2) Риски без проверки sortField/sortDirection:
--    a) Утечка данных: sortField = "(SELECT password_plain FROM injection_lab.users LIMIT 1)"
--    b) Удаление таблицы: sortField = "title; DROP TABLE injection_lab.tasks; --"
--    c) Повышение прав: sortField = "title; UPDATE injection_lab.users SET role_name='admin' WHERE username='alice'; --"
--    d) Разведка БД: sortField = "(SELECT column_name FROM information_schema.columns LIMIT 1)"

-- 3) Безопасная стратегия: БЕЛЫЙ СПИСОК (whitelist)
--    Словарь допустимых значений + значение по умолчанию.


-- =====================================================
-- ЧАСТЬ 3: ИСПРАВЛЕНИЕ УЯЗВИМОСТЕЙ
-- =====================================================

-- =====================================================
-- Задание 3.1: Безопасная аутентификация (параметризация)
-- =====================================================

-- ИСПРАВЛЕННЫЙ КОД:
--
-- async function loginSafe(client, username, password) {
--   const sql = {
--     text:
--       "SELECT user_id, username, role_name " +
--       "FROM injection_lab.users " +
--       "WHERE username = $1 AND password_plain = $2",
--     values: [username, password]
--   };
--   return client.query(sql);
-- }

-- Почему ' OR 1=1 -- больше не работает:
-- $1 воспринимается PostgreSQL как ЛИТЕРАЛ. Строка "' OR 1=1 --"
-- не интерпретируется как SQL, а ищется буквально в поле username.

-- Проверка через PREPARE/EXECUTE:
PREPARE login_safe(TEXT, TEXT) AS
    SELECT user_id, username, role_name
    FROM injection_lab.users
    WHERE username = $1 AND password_plain = $2;

-- Корректный ввод:
EXECUTE login_safe('alice', 'alice123');
-- Результат: 1 строка (alice)

-- Неверный пароль:
EXECUTE login_safe('alice', 'wrong');
-- Результат: 0 строк

-- Вредоносный ввод — БЕЗОПАСНО:
EXECUTE login_safe(''' OR 1=1 --', 'anything');
-- Результат: 0 строк (инъекция НЕ сработала!)

DEALLOCATE login_safe;


-- =====================================================
-- Задание 3.2: Безопасный поиск задач (параметризация)
-- =====================================================

-- ИСПРАВЛЕННЫЙ КОД:
--
-- async function findTasksByStatusSafe(client, status) {
--   return client.query(
--     "SELECT task_id, title, status, priority " +
--     "FROM injection_lab.tasks " +
--     "WHERE status = $1",
--     [status]
--   );
-- }

-- Проверка:
PREPARE find_tasks_safe(TEXT) AS
    SELECT task_id, title, status, priority
    FROM injection_lab.tasks
    WHERE status = $1;

EXECUTE find_tasks_safe('new');
-- Результат: 2 строки (только new)

EXECUTE find_tasks_safe(''' OR 1=1 --');
-- Результат: 0 строк (инъекция НЕ сработала!)

DEALLOCATE find_tasks_safe;


-- =====================================================
-- Задание 3.3: Безопасная сортировка (белые списки)
-- =====================================================

-- ИСПРАВЛЕННЫЙ КОД:
--
-- async function listTasksSafe(client, sortField, sortDirection) {
--   const allowedFields = {
--     created_at: "created_at",
--     priority:   "priority",
--     title:      "title",
--     status:     "status"
--   };
--   const allowedDirections = {
--     asc:  "ASC",
--     desc: "DESC"
--   };
--   const field = allowedFields[sortField] ?? "created_at";
--   const direction = allowedDirections[sortDirection] ?? "DESC";
--
--   const sql =
--     "SELECT task_id, title, priority, created_at, status " +
--     "FROM injection_lab.tasks " +
--     "ORDER BY " + field + " " + direction;
--   return client.query(sql);
-- }

-- Допустимые значения — работает:
SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY title ASC;

SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY priority DESC;

-- Недопустимое значение (title; DROP TABLE ...) → подставится created_at DESC:
SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY created_at DESC;
-- Вредоносная строка полностью проигнорирована!


-- =====================================================
-- ЧАСТЬ 4: ПРОВЕРКА ЗАЩИТЫ НА УРОВНЕ БД
-- =====================================================

-- Задание 4.1: Ограниченная роль приложения
DROP ROLE IF EXISTS web_app_demo;
CREATE ROLE web_app_demo LOGIN PASSWORD 'demo123';

REVOKE ALL ON SCHEMA injection_lab FROM PUBLIC;
GRANT USAGE ON SCHEMA injection_lab TO web_app_demo;
REVOKE ALL ON ALL TABLES IN SCHEMA injection_lab FROM web_app_demo;
GRANT SELECT ON injection_lab.users TO web_app_demo;
GRANT SELECT ON injection_lab.tasks TO web_app_demo;
GRANT UPDATE(status) ON injection_lab.tasks TO web_app_demo;

-- Как это ограничивает ущерб:
-- • DROP TABLE — невозможен (нет прав DDL)
-- • DELETE — невозможен (нет права DELETE)
-- • INSERT — невозможен (нет права INSERT)
-- • UPDATE — только поле status в tasks
-- Даже при инъекции злоумышленник не сможет модифицировать или уничтожить данные

-- Задание 4.2: Проверка матрицы прав
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'web_app_demo'
ORDER BY table_name, privilege_type;

-- Ожидаемый результат:
-- web_app_demo | injection_lab | tasks | SELECT
-- web_app_demo | injection_lab | tasks | UPDATE
-- web_app_demo | injection_lab | users | SELECT

-- Сравнение потенциального ущерба:
-- web_app_demo:     SELECT + UPDATE(status) — минимальный ущерб
-- Владелец схемы:   ВСЕ операции на ВСЕ таблицы — полный контроль
-- Суперпользователь: ВСЕ + pg_shadow, COPY, CREATE EXTENSION — тотальный контроль


-- =====================================================
-- ЧАСТЬ 4 (ДОПОЛНЕНИЕ): ЗАЩИТА СУЩЕСТВУЮЩИХ ТАБЛИЦ app
-- =====================================================
-- Применяем защиту от SQL-инъекций к нашим реальным таблицам:
-- app.users, app.courses, app.enrollments, app.forum_posts и т.д.

-- =====================================================
-- Безопасная аутентификация для app.users
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

-- Вызов в приложении (Node.js):
-- const result = await client.query(
--   'SELECT * FROM app.safe_login($1, $2)',
--   [username, passwordHash]
-- );

-- Проверка:
PREPARE test_app_login(TEXT, TEXT) AS
    SELECT * FROM app.safe_login($1, $2);

EXECUTE test_app_login('student1', 'hash1');
-- Результат: 1 строка (student1)

EXECUTE test_app_login(''' OR 1=1 --', 'anything');
-- Результат: 0 строк — инъекция НЕ работает!

DEALLOCATE test_app_login;


-- =====================================================
-- Безопасный поиск курсов для app.courses
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

-- Вызов: SELECT * FROM app.safe_search_courses($1)
-- Проверка:
PREPARE test_search_courses(TEXT) AS
    SELECT * FROM app.safe_search_courses($1);

EXECUTE test_search_courses('Python');
-- Результат: 1 строка (Основы Python, published)

EXECUTE test_search_courses(''' OR 1=1 --');
-- Результат: 0 строк — инъекция НЕ работает!

DEALLOCATE test_search_courses;


-- =====================================================
-- Безопасная выборка зачислений для app.enrollments
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

-- Вызов: SELECT * FROM app.safe_get_enrollments($1)
-- Тип INTEGER не позволяет передать строку '1 OR 1=1' — ошибка типизации


-- =====================================================
-- Безопасная сортировка курсов (белый список)
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
    -- Белый список полей
    v_field := CASE p_sort_field
        WHEN 'title'      THEN 'title'
        WHEN 'price'      THEN 'price'
        WHEN 'status'     THEN 'status'
        WHEN 'created_at' THEN 'created_at'
        ELSE 'created_at'
    END;

    -- Белый список направлений
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

-- Проверка:
SELECT * FROM app.safe_list_courses('title', 'asc');
SELECT * FROM app.safe_list_courses('price', 'desc');
-- Вредоносный ввод → подставится значение по умолчанию:
SELECT * FROM app.safe_list_courses('title; DROP TABLE app.users; --', 'asc');
-- Результат: сортировка по created_at DESC — атака проигнорирована!


-- =====================================================
-- Безопасная работа с форумом для app.forum_posts
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
-- Безопасная отправка работы для app.submissions
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
-- Безопасное обновление статуса зачисления (белый список)
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
    -- Белый список статусов
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
-- Ограниченная роль приложения для схемы app
-- =====================================================

DROP ROLE IF EXISTS web_app_secure;
CREATE ROLE web_app_secure LOGIN PASSWORD 'SecureApp2024!';

GRANT USAGE ON SCHEMA app TO web_app_secure;

-- Только чтение на основные таблицы
GRANT SELECT ON app.users TO web_app_secure;
GRANT SELECT ON app.courses TO web_app_secure;
GRANT SELECT ON app.lessons TO web_app_secure;
GRANT SELECT ON app.assignments TO web_app_secure;
GRANT SELECT ON app.enrollments TO web_app_secure;
GRANT SELECT ON app.submissions TO web_app_secure;
GRANT SELECT ON app.forum_posts TO web_app_secure;
GRANT SELECT ON app.certificates TO web_app_secure;

-- Ограниченная запись (только необходимое)
GRANT INSERT ON app.submissions TO web_app_secure;
GRANT UPDATE (status) ON app.enrollments TO web_app_secure;
GRANT INSERT ON app.forum_posts TO web_app_secure;
GRANT UPDATE (content, updated_at) ON app.forum_posts TO web_app_secure;
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

-- Логирование
GRANT INSERT ON app.access_logs TO web_app_secure;
GRANT USAGE ON SEQUENCE app.access_logs_log_id_seq TO web_app_secure;

-- Проверка прав:
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'web_app_secure'
ORDER BY table_name, privilege_type;


-- =====================================================
-- ЧАСТЬ 5: ТАБЛИЦА «БЫЛО / СТАЛО»
-- =====================================================

-- ┌──────────────────────┬────────────────────────────────────┬──────────────────────────────┬───────────────────────────────────────────┬──────────────────┐
-- │ Фрагмент             │ Проблема                           │ Опасный пример ввода         │ Исправление                               │ Мера защиты      │
-- ├──────────────────────┼────────────────────────────────────┼──────────────────────────────┼───────────────────────────────────────────┼──────────────────┤
-- │ Аутентификация       │ Конкатенация username и password   │ username: ' OR 1=1 --        │ Параметризованный запрос ($1, $2)         │ ПАРАМЕТРИЗАЦИЯ   │
-- │ (login)              │ в SQL без экранировки              │ → обход аутентификации,      │ через client.query({ text, values })     │                  │
-- │                      │                                    │ доступ ко ВСЕМ пользователям │ + функция app.safe_login($1, $2)         │                  │
-- ├──────────────────────┼────────────────────────────────────┼──────────────────────────────┼───────────────────────────────────────────┼──────────────────┤
-- │ Поиск задач/курсов   │ Конкатенация status/keyword        │ status: ' OR 1=1 --          │ Параметризованный запрос ($1)             │ ПАРАМЕТРИЗАЦИЯ   │
-- │ (findTasksByStatus,  │ в WHERE без экранировки            │ → возврат ВСЕХ записей       │ через client.query(sql, [status])        │                  │
-- │  searchCourses)      │                                    │ включая скрытые              │ + функция app.safe_search_courses($1)    │                  │
-- ├──────────────────────┼────────────────────────────────────┼──────────────────────────────┼───────────────────────────────────────────┼──────────────────┤
-- │ Сортировка           │ Прямая подстановка sortField       │ sortField: title; DROP TABLE │ Белый список allowedFields +             │ БЕЛЫЕ СПИСКИ     │
-- │ (listTasks,          │ и sortDirection в ORDER BY         │ injection_lab.tasks; --      │ allowedDirections со значениями           │                  │
-- │  listCourses)        │ без проверки                       │ → удаление таблицы           │ по умолчанию + функция                   │                  │
-- │                      │                                    │                              │ app.safe_list_courses($1, $2)             │                  │
-- └──────────────────────┴────────────────────────────────────┴──────────────────────────────┴───────────────────────────────────────────┴──────────────────┘

-- Итого:
-- ПАРАМЕТРИЗАЦИЯ применялась: Аутентификация ($1, $2), Поиск задач/курсов ($1), Зачисления ($1), Форум ($1, $2), Сдача работ ($1, $2, $3)
-- БЕЛЫЕ СПИСКИ применялись:   Сортировка (allowedFields, allowedDirections, CASE), Обновление статуса (допустимые значения active/completed/dropped)

-- Многоуровневая защита нашей БД:
-- 1 уровень: Параметризованные запросы / белые списки (код приложения)
-- 2 уровень: Хранимые функции с SECURITY DEFINER (safe_login, safe_search_courses и т.д.)
-- 3 уровень: Ограниченные роли web_app_demo и web_app_secure (минимальные привилегии)
-- 4 уровень: RLS-политики (строковая безопасность, реализовано в практиках 3-6 выше)
-- 5 уровень: RBAC (ролевой доступ app_guest → app_student → ... → app_admin, реализовано выше)

-- =====================================================
-- КОНЕЦ ПРАКТИКИ 9
-- =====================================================

