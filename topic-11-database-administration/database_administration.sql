-- ================================================================
-- DATABASE ADMINISTRATION TEMPLATE (TOPIC 11)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) CREATE ROLE statements for at least 2 distinct roles.
--    Example roles: read-only analyst, read-write editor.
--
-- 2) GRANT statements assigning appropriate permissions to each role:
--    - Read-only role: GRANT SELECT ON ALL TABLES IN SCHEMA ...
--    - Read-write role: GRANT SELECT, INSERT, UPDATE, DELETE ...
--
-- 3) CREATE USER statements for at least 2 users.
--    Each user must be assigned to one of the defined roles.
--
-- 4) Comments before each section explaining the rationale:
--    - Why this role exists
--    - What access it should and should not have
--
-- RECOMMENDED ORDER:
-- 1) Roles + their GRANTs
-- 2) Users + GRANT ROLE TO USER
-- 3) Optional: REVOKE statements for fine-grained restrictions
-- 4) Optional cleanup block (commented out by default):
--    -- DROP USER ...; DROP ROLE ...;
--
-- IMPORTANT:
-- - Use explicit GRANT / REVOKE statements — do not rely on defaults.
-- - Roles must have meaningfully different permission levels.
-- - Script must execute in PostgreSQL without errors.
-- ================================================================

-- Add your script below this line


-- ================================================================
-- [Oleksandr] Ролі та користувачі для роботи з абонементами
-- ================================================================
-- Таблиці моєї зони: membership_plans, memberships
-- (+ views VIEW 13-20 з views.sql).
--
-- Принцип least privilege: кожна роль отримує рівно ті права,
-- які потрібні для її роботи, і нічого більше.
--
--   fc_membership_analyst  - READ-ONLY. Аналітик продажів:
--       бачить тарифи, абонементи та звіти, нічого не змінює
--       і НЕ бачить персональних даних клієнтів (members).
--
--   fc_membership_manager  - READ-WRITE. Менеджер рецепції:
--       оформлює, продовжує, заморожує абонементи; бачить лише
--       ім'я та email клієнта; не може змінювати ціни тарифів
--       і не може видаляти абонементи (це історія покупок -
--       для скасування є status = 'cancelled').
--
-- Ролі створені без LOGIN (NOLOGIN) - це "набори прав".
-- Користувачі мають LOGIN і отримують права через членство в ролі.
-- Так права змінюються в одному місці (ролі), а не для кожної людини.
--
-- Порядок запуску: ddl.sql -> dml.sql -> views.sql -> цей скрипт.
-- Запускати від імені власника схеми або суперкористувача.
-- ================================================================


-- ================================================
-- 1) Базове обмеження доступу (REVOKE для PUBLIC)
-- ================================================
-- PUBLIC - це "усі ролі в кластері". За замовчуванням PUBLIC
-- і так не має прав на нову схему та її таблиці, тому ці REVOKE
-- нічого не забирають у чистій базі. Вони фіксують правило явно:
-- доступ мають лише ролі, яким його видано нижче, навіть якщо
-- хтось раніше видав права для PUBLIC.
-- Увага: це діє на всю схему, а не лише на таблиці абонементів.

REVOKE ALL ON SCHEMA fitness_center_team4 FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA fitness_center_team4 FROM PUBLIC;


-- ================================================
-- 2) Створення ролей (без LOGIN)
-- ================================================

-- Ролі існують на рівні всього кластера, а не однієї бази.
-- IF NOT EXISTS дозволяє запустити скрипт повторно без помилки
-- "role already exists" (у PostgreSQL немає CREATE ROLE IF NOT EXISTS).
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'fc_membership_analyst') THEN
        CREATE ROLE fc_membership_analyst NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'fc_membership_manager') THEN
        CREATE ROLE fc_membership_manager NOLOGIN;
    END IF;
END
$$;


-- ================================================
-- 3) Спільні права: підключення до БД і доступ до схеми
-- ================================================
-- CONNECT - право підключитися до бази. Назва бази може відрізнятися
-- в кожного учасника, тому беремо її з current_database().
-- USAGE на схему - право "бачити" об'єкти в ній (але не дані).
-- CREATE на схему НЕ видаємо: жодна з ролей не може створювати
-- чи видаляти таблиці - структуру змінює лише власник.

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO fc_membership_analyst, fc_membership_manager',
                   current_database());
END
$$;

GRANT USAGE ON SCHEMA fitness_center_team4
    TO fc_membership_analyst, fc_membership_manager;


-- ================================================
-- 4) fc_membership_analyst - READ-ONLY
-- ================================================
-- Лише SELECT. Таблиці membership_plans і memberships не містять
-- персональних даних (у memberships є тільки member_id), тому
-- аналітик може рахувати продажі, не бачачи імен і контактів.
-- До members доступу немає взагалі.

GRANT SELECT ON
    fitness_center_team4.membership_plans,
    fitness_center_team4.memberships
TO fc_membership_analyst;

-- Звітні views без персональних даних
GRANT SELECT ON
    fitness_center_team4.view_plan_price_list,
    fitness_center_team4.view_active_memberships,
    fitness_center_team4.view_plan_sales_summary,
    fitness_center_team4.view_membership_history,
    fitness_center_team4.view_active_memberships_by_plan
TO fc_membership_analyst;


-- ================================================
-- 5) fc_membership_manager - READ-WRITE
-- ================================================

-- memberships: читати й оформлювати нові абонементи
GRANT SELECT, INSERT
    ON fitness_center_team4.memberships
    TO fc_membership_manager;

-- Column-level UPDATE: лише status (заморозка, скасування) та
-- end_date (продовження). Клієнта, тариф і дату початку вже
-- проданого абонемента менеджер змінити не може.
GRANT UPDATE (status, end_date)
    ON fitness_center_team4.memberships
    TO fc_membership_manager;

-- DELETE менеджеру не видано. REVOKE фіксує цю заборону явно:
-- абонемент - це історія покупок і фінансова інформація.
-- Скасування робиться через UPDATE status = 'cancelled'.
REVOKE DELETE
    ON fitness_center_team4.memberships
    FROM fc_membership_manager;

-- membership_plans: лише читати. Ціни й тарифи затверджує
-- керівництво, а не менеджер рецепції.
GRANT SELECT
    ON fitness_center_team4.membership_plans
    TO fc_membership_manager;

-- members: column-level SELECT - лише стовпці, потрібні, щоб знайти
-- клієнта й оформити абонемент. phone і birth_date приховано.
GRANT SELECT (member_id, first_name, last_name, email)
    ON fitness_center_team4.members
    TO fc_membership_manager;

-- Views для щоденної роботи рецепції
GRANT SELECT ON
    fitness_center_team4.view_plan_price_list,
    fitness_center_team4.view_active_memberships,
    fitness_center_team4.view_expiring_memberships,
    fitness_center_team4.view_member_memberships,
    fitness_center_team4.view_returning_members
TO fc_membership_manager;

-- Оновлюваний view з WITH CHECK OPTION (VIEW 20): зручний шлях
-- для продовження активних абонементів. Це не обмеження доступу:
-- статус менеджер може змінити й напряму в memberships
-- (у межах column-level UPDATE вище).
GRANT SELECT, UPDATE
    ON fitness_center_team4.view_editable_active_memberships
    TO fc_membership_manager;


-- ================================================
-- 6) Створення користувачів і призначення ролей
-- ================================================
-- Паролі тут - навчальні заглушки. У реальній системі паролі
-- не зберігають у скрипті в репозиторії: їх задають окремо
-- (\password у psql) або через менеджер секретів.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'membership_analyst_user') THEN
        CREATE USER membership_analyst_user WITH PASSWORD 'change_me_analyst';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'membership_manager_user') THEN
        CREATE USER membership_manager_user WITH PASSWORD 'change_me_manager';
    END IF;
END
$$;

GRANT fc_membership_analyst TO membership_analyst_user;
GRANT fc_membership_manager TO membership_manager_user;


-- ================================================
-- 7) Перевірка прав (можна запускати від власника)
-- ================================================
-- has_table_privilege / has_column_privilege показують, чи має
-- користувач право, з урахуванням прав його ролі.
-- Очікуваний результат зазначено в назві стовпця.

SELECT
    has_table_privilege('membership_analyst_user', 'fitness_center_team4.memberships', 'SELECT')  AS analyst_select_true,
    has_table_privilege('membership_analyst_user', 'fitness_center_team4.memberships', 'INSERT')  AS analyst_insert_false,
    has_table_privilege('membership_analyst_user', 'fitness_center_team4.members',     'SELECT')  AS analyst_members_false,
    -- UPDATE видано лише на стовпці, тому has_table_privilege дав би false;
    -- has_any_column_privilege перевіряє, чи можна оновити хоч один стовпець
    has_any_column_privilege('membership_manager_user', 'fitness_center_team4.memberships', 'UPDATE') AS manager_update_true,
    has_table_privilege('membership_manager_user', 'fitness_center_team4.memberships', 'DELETE')  AS manager_delete_false,
    has_table_privilege('membership_manager_user', 'fitness_center_team4.membership_plans', 'UPDATE') AS manager_plan_update_false,
    has_column_privilege('membership_manager_user', 'fitness_center_team4.members', 'email', 'SELECT') AS manager_email_true,
    has_column_privilege('membership_manager_user', 'fitness_center_team4.members', 'phone', 'SELECT') AS manager_phone_false,
    has_column_privilege('membership_manager_user', 'fitness_center_team4.memberships', 'end_date', 'UPDATE') AS manager_end_date_true,
    has_column_privilege('membership_manager_user', 'fitness_center_team4.memberships', 'plan_id',  'UPDATE') AS manager_plan_id_false;


-- ================================================
-- 8) Демонстрація від імені користувачів (запускати вручну)
-- ================================================
-- SET ROLE тимчасово "перемикає" сесію на користувача,
-- RESET ROLE повертає назад. Прибрати -- і запускати блоками.

-- --- Аналітик: читати можна ---
-- SET ROLE membership_analyst_user;
-- SELECT * FROM fitness_center_team4.view_plan_sales_summary;
-- --- Аналітик: змінювати не можна ---
-- Очікується: permission denied for table memberships
-- UPDATE fitness_center_team4.memberships SET status = 'expired';
-- --- Аналітик: персональні дані недоступні ---
-- Очікується: permission denied for table members
-- SELECT * FROM fitness_center_team4.members;
-- RESET ROLE;

-- --- Менеджер: оформлення та зміна абонемента дозволені ---
-- SET ROLE membership_manager_user;
-- BEGIN;
-- UPDATE fitness_center_team4.memberships
-- SET status = 'frozen'
-- WHERE membership_id = 2;
-- ROLLBACK;
-- --- Менеджер: змінити тариф уже проданого абонемента не можна ---
-- Очікується: permission denied for table memberships
-- UPDATE fitness_center_team4.memberships SET plan_id = 1 WHERE membership_id = 2;
-- --- Менеджер: видалити абонемент не можна ---
-- Очікується: permission denied for table memberships
-- DELETE FROM fitness_center_team4.memberships WHERE membership_id = 2;
-- --- Менеджер: змінити ціну тарифу не можна ---
-- Очікується: permission denied for table membership_plans
-- UPDATE fitness_center_team4.membership_plans SET price = 0;
-- --- Менеджер: телефон клієнта прихований ---
-- Очікується: permission denied for table members
-- SELECT phone FROM fitness_center_team4.members;
-- RESET ROLE;


-- ================================================
-- 9) Optional cleanup після тестування
-- ================================================
-- Роль не можна видалити, поки в неї є права на об'єкти,
-- тому спочатку DROP OWNED (забирає всі видані права), потім DROP.

-- DROP OWNED BY membership_analyst_user, membership_manager_user;
-- DROP USER IF EXISTS membership_analyst_user;
-- DROP USER IF EXISTS membership_manager_user;
-- DROP OWNED BY fc_membership_analyst, fc_membership_manager;
-- DROP ROLE IF EXISTS fc_membership_analyst;
-- DROP ROLE IF EXISTS fc_membership_manager;
