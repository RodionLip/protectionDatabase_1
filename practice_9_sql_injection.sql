-- =====================================================
-- ПРАКТИКА 9: Анализ уязвимого к SQL-инъекциям кода
-- приложения и его исправление
-- =====================================================
-- Предметная область: Корпоративная система управления задачами
-- База: online_learning_v2 (существующая), схема: injection_lab
-- =====================================================


-- =====================================================
-- ЧАСТЬ 1: ПОДГОТОВКА ЛАБОРАТОРНОГО СТЕНДА
-- =====================================================

-- Задание 1.1: Создание схемы и тестовых данных
-- Создаём отдельную схему, чтобы не затрагивать основную схему app

CREATE SCHEMA IF NOT EXISTS injection_lab;

DROP TABLE IF EXISTS injection_lab.tasks CASCADE;
DROP TABLE IF EXISTS injection_lab.users CASCADE;

-- Таблица пользователей (упрощённая, с открытым паролем для демонстрации)
CREATE TABLE injection_lab.users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_plain TEXT NOT NULL
);

-- Таблица задач
CREATE TABLE injection_lab.tasks (
    task_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'new',
    priority TEXT NOT NULL DEFAULT 'medium',
    assignee_username TEXT NOT NULL REFERENCES injection_lab.users(username),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Загрузка тестовых данных
INSERT INTO injection_lab.users (username, full_name, role_name, email, password_plain) VALUES
('alice', 'Alice Ivanova',   'employee', 'alice@corp.local', 'alice123'),
('bob',   'Bob Petrov',      'manager',  'bob@corp.local',   'bob123'),
('carol', 'Carol Sidorova',  'admin',    'carol@corp.local',  'carol123');

INSERT INTO injection_lab.tasks (title, description, status, priority, assignee_username) VALUES
('Подготовить отчёт',       'Собрать метрики по проекту',       'in_progress', 'high',     'alice'),
('Проверить права доступа', 'Аудит ролей PostgreSQL',           'new',         'critical', 'bob'),
('Обновить регламент',      'Документация по реагированию',     'done',        'medium',   'carol'),
('Закрыть инцидент',        'Проверить журналы событий',        'new',         'high',     'alice');

-- Проверка: в users должно быть 3 строки, в tasks — 4 строки
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM injection_lab.users
UNION ALL
SELECT 'tasks', COUNT(*) FROM injection_lab.tasks;


-- =====================================================
-- ЧАСТЬ 2: АНАЛИЗ УЯЗВИМЫХ ФРАГМЕНТОВ КОДА
-- =====================================================

-- =====================================================
-- Задание 2.1: Уязвимая аутентификация
-- =====================================================

-- Исходный уязвимый код (JavaScript / Node.js + pg):
--
-- async function login(client, username, password) {
--   const sql =
--     "SELECT user_id, username, role_name " +
--     "FROM injection_lab.users " +
--     "WHERE username = '" + username + "' " +
--     "AND password_plain = '" + password + "'";
--
--   return client.query(sql);
-- }

-- АНАЛИЗ УЯЗВИМОСТИ:
-- Код уязвим, потому что пользовательский ввод (username, password)
-- подставляется в SQL-запрос через конкатенацию строк без какой-либо
-- экранировки или параметризации. Злоумышленник может внедрить
-- произвольный SQL-код через поля ввода.

-- Пример вредоносного ввода для обхода аутентификации:
-- username: ' OR 1=1 --
-- password: (любое значение, например: anything)

-- Итоговый запрос после подстановки вредоносного логина:
-- SELECT user_id, username, role_name
-- FROM injection_lab.users
-- WHERE username = '' OR 1=1 --' AND password_plain = 'anything'

-- Разбор:
-- 1) Условие username = '' — ложно для всех пользователей
-- 2) OR 1=1 — всегда истинно, делая всё условие WHERE истинным
-- 3) -- комментирует остаток запроса (проверку пароля)
-- 4) Результат: возвращаются ВСЕ пользователи из таблицы

-- Демонстрация — нормальный запрос (корректный логин):
SELECT user_id, username, role_name
FROM injection_lab.users
WHERE username = 'alice' AND password_plain = 'alice123';
-- Результат: 1 строка (alice)

-- Демонстрация — атакованный запрос (инъекция в username):
SELECT user_id, username, role_name
FROM injection_lab.users
WHERE username = '' OR 1=1 --' AND password_plain = 'anything';
-- Результат: ВСЕ 3 строки — обход аутентификации!

-- Данные, которые может получить злоумышленник:
-- • user_id, username и role_name ВСЕХ пользователей
-- • Приложение может взять первую строку результата и
--   авторизовать атакующего как этого пользователя
-- • Если первая строка — admin (carol), атакующий получит
--   привилегии администратора

-- Ещё один опасный вариант — инъекция через UNION:
-- username: ' UNION SELECT 1, email, password_plain FROM injection_lab.users --
-- Это позволит извлечь email и пароли всех пользователей.


-- =====================================================
-- Задание 2.2: Уязвимый поиск задач
-- =====================================================

-- Исходный уязвимый код:
--
-- async function findTasksByStatus(client, status) {
--   const sql =
--     "SELECT task_id, title, status, priority " +
--     "FROM injection_lab.tasks " +
--     "WHERE status = '" + status + "'";
--
--   return client.query(sql);
-- }

-- АНАЛИЗ УЯЗВИМОСТИ:
-- Аналогичная проблема — конкатенация пользовательского ввода
-- в SQL без параметризации.

-- Пример инъекции, возвращающей ВСЕ задачи:
-- status: ' OR 1=1 --

-- Итоговый запрос:
-- SELECT task_id, title, status, priority
-- FROM injection_lab.tasks
-- WHERE status = '' OR 1=1 --'

-- Объяснение работы комментария «--»:
-- Двойной дефис (--) в SQL означает начало однострочного комментария.
-- Всё, что стоит после --, PostgreSQL игнорирует. В данном случае
-- комментируется закрывающая кавычка ', которую добавляет код.
-- Без комментария строка была бы синтаксически некорректной.

-- Демонстрация — нормальный запрос:
SELECT task_id, title, status, priority
FROM injection_lab.tasks
WHERE status = 'new';
-- Результат: 2 строки (задачи со статусом 'new')

-- Демонстрация — атакованный запрос:
SELECT task_id, title, status, priority
FROM injection_lab.tasks
WHERE status = '' OR 1=1 --';
-- Результат: ВСЕ 4 строки — утечка всех задач!

-- Сравнение результатов:
-- Нормальный: 2 задачи (new)     — только «Проверить права доступа» и «Закрыть инцидент»
-- Атакованный: 4 задачи (все)    — включая in_progress и done


-- =====================================================
-- Задание 2.3: Уязвимая сортировка
-- =====================================================

-- Исходный уязвимый код:
--
-- async function listTasks(client, sortField, sortDirection) {
--   const sql =
--     "SELECT task_id, title, priority, created_at " +
--     "FROM injection_lab.tasks " +
--     "ORDER BY " + sortField + " " + sortDirection;
--
--   return client.query(sql);
-- }

-- АНАЛИЗ УЯЗВИМОСТИ:

-- 1) Почему параметризация неприменима напрямую к имени столбца:
--    Параметры ($1, $2) в PostgreSQL подставляются как ЗНАЧЕНИЯ (литералы),
--    а не как идентификаторы. Имя столбца — это идентификатор SQL.
--    Если написать ORDER BY $1, PostgreSQL интерпретирует $1 как строковое
--    значение, а не как имя колонки, и запрос либо вернёт ошибку,
--    либо будет сортировать по константе (т.е. без сортировки).

-- 2) Риски использования sortField и sortDirection без проверки:
--    a) Утечка данных через подзапрос:
--       sortField = "(SELECT password_plain FROM injection_lab.users LIMIT 1)"
--       — Можно извлечь данные из других таблиц через ORDER BY.
--    b) Деструктивные действия:
--       sortField = "title; DROP TABLE injection_lab.tasks; --"
--       — Удаление таблицы (если у роли есть права).
--    c) Модификация данных:
--       sortField = "title; UPDATE injection_lab.users SET role_name='admin' WHERE username='alice'; --"
--       — Повышение привилегий пользователя.
--    d) Определение структуры БД:
--       sortField = "(SELECT column_name FROM information_schema.columns LIMIT 1)"
--       — Разведка схемы базы данных.

-- 3) Безопасная стратегия исправления:
--    Использование БЕЛОГО СПИСКА (whitelist) — словаря допустимых значений.
--    Вместо подстановки ввода напрямую, проверяем, входит ли значение
--    в список разрешённых полей/направлений. Если нет — используем значение
--    по умолчанию.


-- =====================================================
-- ЧАСТЬ 3: ИСПРАВЛЕНИЕ УЯЗВИМОСТЕЙ
-- =====================================================

-- =====================================================
-- Задание 3.1: Безопасная аутентификация
-- =====================================================

-- Исправленный код с параметризацией:
--
-- async function loginSafe(client, username, password) {
--   const sql = {
--     text:
--       "SELECT user_id, username, role_name " +
--       "FROM injection_lab.users " +
--       "WHERE username = $1 AND password_plain = $2",
--     values: [username, password]
--   };
--
--   return client.query(sql);
-- }

-- Почему инъекция ' OR 1=1 -- больше не работает:
-- При параметризации значение $1 воспринимается PostgreSQL как ЛИТЕРАЛ.
-- Строка "' OR 1=1 --" не интерпретируется как SQL-код, а передаётся
-- целиком как значение для сравнения с полем username.
-- Фактически выполняется:
-- WHERE username = ''' OR 1=1 --' AND password_plain = 'anything'
-- PostgreSQL ищет пользователя с username, равным буквально «' OR 1=1 --».
-- Такого пользователя нет — результат пустой.

-- Проверка для корректного ввода (эмуляция параметризации через PREPARE):
PREPARE login_safe(TEXT, TEXT) AS
    SELECT user_id, username, role_name
    FROM injection_lab.users
    WHERE username = $1 AND password_plain = $2;

-- Корректный ввод — работает:
EXECUTE login_safe('alice', 'alice123');
-- Результат: 1 строка (alice, employee)

-- Неверный пароль — пусто:
EXECUTE login_safe('alice', 'wrong_password');
-- Результат: 0 строк

-- Вредоносный ввод — безопасно:
EXECUTE login_safe(''' OR 1=1 --', 'anything');
-- Результат: 0 строк (инъекция НЕ сработала!)

DEALLOCATE login_safe;


-- =====================================================
-- Задание 3.2: Безопасный поиск задач
-- =====================================================

-- Исправленный код с параметризацией:
--
-- async function findTasksByStatusSafe(client, status) {
--   return client.query(
--     "SELECT task_id, title, status, priority " +
--     "FROM injection_lab.tasks " +
--     "WHERE status = $1",
--     [status]
--   );
-- }

-- Проверка через PREPARE:
PREPARE find_tasks_safe(TEXT) AS
    SELECT task_id, title, status, priority
    FROM injection_lab.tasks
    WHERE status = $1;

-- Корректный ввод:
EXECUTE find_tasks_safe('new');
-- Результат: 2 строки (задачи со статусом new)

-- Вредоносный ввод — безопасно:
EXECUTE find_tasks_safe(''' OR 1=1 --');
-- Результат: 0 строк (ищется статус с буквальным текстом "' OR 1=1 --")

DEALLOCATE find_tasks_safe;


-- =====================================================
-- Задание 3.3: Безопасная сортировка через белые списки
-- =====================================================

-- Исправленный код с белым списком:
--
-- async function listTasksSafe(client, sortField, sortDirection) {
--   const allowedFields = {
--     created_at: "created_at",
--     priority:   "priority",
--     title:      "title",
--     status:     "status"
--   };
--
--   const allowedDirections = {
--     asc:  "ASC",
--     desc: "DESC"
--   };
--
--   // Если значение не в белом списке — используем значение по умолчанию
--   const field = allowedFields[sortField] ?? "created_at";
--   const direction = allowedDirections[sortDirection] ?? "DESC";
--
--   const sql =
--     "SELECT task_id, title, priority, created_at, status " +
--     "FROM injection_lab.tasks " +
--     "ORDER BY " + field + " " + direction;
--
--   return client.query(sql);
-- }

-- Объяснение механизма защиты:
-- 1) allowedFields — словарь, ключи которого = допустимые имена столбцов.
--    Оператор ?? (nullish coalescing) возвращает "created_at", если ключа нет.
-- 2) allowedDirections — словарь с двумя допустимыми направлениями: ASC и DESC.
-- 3) Любое вредоносное значение (например, "title; DROP TABLE ...") просто
--    не найдётся в словаре, и будет подставлено значение по умолчанию.

-- Демонстрация для допустимых значений:

-- sortField = 'title', sortDirection = 'asc':
SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY title ASC;

-- sortField = 'priority', sortDirection = 'desc':
SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY priority DESC;

-- Демонстрация для недопустимого значения:
-- sortField = 'title; DROP TABLE injection_lab.tasks; --'
-- В коде: allowedFields['title; DROP TABLE injection_lab.tasks; --'] => undefined
-- Результат: field = "created_at" (значение по умолчанию)
-- Итоговый запрос будет безопасным:
SELECT task_id, title, priority, created_at, status
FROM injection_lab.tasks
ORDER BY created_at DESC;
-- Вредоносная строка полностью проигнорирована!


-- =====================================================
-- ЧАСТЬ 4: ПРОВЕРКА ЗАЩИТЫ НА УРОВНЕ БД
-- =====================================================

-- =====================================================
-- Задание 4.1: Создание ограниченной роли приложения
-- =====================================================

-- Даже если код приложения безопасен, роль подключения к БД должна
-- иметь минимально необходимые привилегии (принцип наименьших привилегий).

DROP ROLE IF EXISTS web_app_demo;
CREATE ROLE web_app_demo LOGIN PASSWORD 'demo123';

-- Отзываем все права по умолчанию
REVOKE ALL ON SCHEMA injection_lab FROM PUBLIC;

-- Выдаём доступ к схеме
GRANT USAGE ON SCHEMA injection_lab TO web_app_demo;

-- Отзываем все права на таблицы (на случай наследования)
REVOKE ALL ON ALL TABLES IN SCHEMA injection_lab FROM web_app_demo;

-- Выдаём только SELECT на users (для аутентификации)
GRANT SELECT ON injection_lab.users TO web_app_demo;

-- Выдаём только SELECT на tasks (для отображения задач)
GRANT SELECT ON injection_lab.tasks TO web_app_demo;

-- Дополнительно: разрешаем менять статус задач (если нужно)
GRANT UPDATE (status) ON injection_lab.tasks TO web_app_demo;

-- Объяснение, как это ограничит ущерб при уязвимости:
--
-- 1) DROP TABLE — невозможен: у web_app_demo нет права DROP/CREATE
--    на таблицы в схеме injection_lab.
--
-- 2) DELETE FROM — невозможен: нет права DELETE на таблицы.
--
-- 3) INSERT — невозможен: нет права INSERT, злоумышленник не сможет
--    добавить поддельных пользователей или задачи.
--
-- 4) UPDATE — ограничен: можно обновить ТОЛЬКО поле status в tasks.
--    Нельзя изменить password_plain, role_name, email и т.д.
--
-- 5) SELECT — разрешён, но это единственная операция. Даже при успешной
--    инъекции злоумышленник увидит только данные из users и tasks,
--    но не сможет модифицировать или уничтожить их.
--
-- Сравнение с суперпользователем:
-- • Суперпользователь: DROP TABLE, DELETE, UPDATE любых полей,
--   доступ к pg_shadow (хеши паролей), CREATE EXTENSION, COPY и т.д.
-- • web_app_demo: только SELECT + UPDATE(status) — минимальный ущерб.


-- =====================================================
-- Задание 4.2: Проверка матрицы прав
-- =====================================================

SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'web_app_demo'
ORDER BY table_name, privilege_type;

-- Ожидаемый результат:
--  grantee      | table_schema  | table_name | privilege_type
-- --------------+---------------+------------+----------------
--  web_app_demo | injection_lab | tasks      | SELECT
--  web_app_demo | injection_lab | tasks      | UPDATE
--  web_app_demo | injection_lab | users      | SELECT

-- Сравнение с подключением под владельцем схемы или суперпользователем:
--
-- | Параметр              | web_app_demo         | Владелец схемы         | Суперпользователь     |
-- |-----------------------|----------------------|------------------------|-----------------------|
-- | SELECT                | users, tasks         | ВСЕ таблицы            | ВСЕ + системные       |
-- | INSERT                | —                    | ВСЕ таблицы            | ВСЕ                   |
-- | UPDATE                | tasks.status         | ВСЕ поля ВСЕХ таблиц   | ВСЕ                   |
-- | DELETE                | —                    | ВСЕ таблицы            | ВСЕ                   |
-- | DROP/ALTER TABLE      | —                    | ДА                     | ДА                    |
-- | Доступ к pg_shadow    | —                    | —                      | ДА                    |
-- | CREATE EXTENSION      | —                    | —                      | ДА                    |
-- | COPY TO/FROM файлов   | —                    | —                      | ДА                    |
--
-- Вывод: при использовании web_app_demo даже успешная SQL-инъекция
-- сможет прочитать данные, но НЕ сможет:
-- • Удалить таблицы или данные
-- • Изменить пароли или роли пользователей
-- • Получить доступ к системным каталогам
-- • Выполнить файловые операции на сервере


-- =====================================================
-- ЧАСТЬ 5: ДОКУМЕНТИРОВАНИЕ РЕЗУЛЬТАТОВ (см. отдельный файл отчёта)
-- =====================================================

-- Таблица «было / стало» приведена ниже для справки:
--
-- +------------------+----------------------------------+---------------------------+----------------------------------------------+
-- | Фрагмент         | Проблема                         | Опасный пример ввода      | Исправление                                  |
-- +------------------+----------------------------------+---------------------------+----------------------------------------------+
-- | Аутентификация   | Конкатенация username и password  | username: ' OR 1=1 --    | Параметризованный запрос ($1, $2)            |
-- |                  | в SQL без экранировки            |                           | через client.query({ text, values })         |
-- +------------------+----------------------------------+---------------------------+----------------------------------------------+
-- | Поиск задач      | Конкатенация status              | status: ' OR 1=1 --      | Параметризованный запрос ($1)                |
-- |                  | в WHERE без экранировки          |                           | через client.query(sql, [status])            |
-- +------------------+----------------------------------+---------------------------+----------------------------------------------+
-- | Сортировка       | Прямая подстановка sortField     | sortField:                | Белый список (allowedFields,                 |
-- |                  | и sortDirection в ORDER BY       | title; DROP TABLE ...     | allowedDirections) + значения по умолчанию   |
-- +------------------+----------------------------------+---------------------------+----------------------------------------------+
--
-- Где применялась параметризация:  Аутентификация ($1, $2), Поиск задач ($1)
-- Где применялись белые списки:    Сортировка (allowedFields, allowedDirections)


-- =====================================================
-- КОНЕЦ ПРАКТИКИ 9
-- =====================================================
