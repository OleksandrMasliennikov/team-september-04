-- ================================================================
-- FUNCTIONS & STORED PROCEDURES TEMPLATE (TOPIC 12)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
--
-- FUNCTIONS (at least 3):
--   - Each function should encapsulate reusable logic or a
--     calculation relevant to your project domain.
--   - Use CREATE OR REPLACE FUNCTION ... RETURNS ...
--
-- STORED PROCEDURES — SELECT / INSERT (at least 2):
--   - Procedures that retrieve data or insert new records.
--   - Use CREATE OR REPLACE PROCEDURE ...
--
-- STORED PROCEDURES — UPDATE (at least 2):
--   - Procedures that modify existing records.
--
-- FOR EACH FUNCTION / PROCEDURE, ADD COMMENTS EXPLAINING:
--   - Purpose: what it does
--   - Parameters: name, type, meaning
--   - Expected behavior / return value
--
-- TEST CALLS:
--   - Include at least one example call per function/procedure
--     (SELECT my_function(...) or CALL my_procedure(...))
--
-- OPTIONAL:
--   - EXCEPTION blocks for error handling
--   - Transaction management with BEGIN / COMMIT / ROLLBACK
--
-- RECOMMENDED ORDER:
-- 1) Functions
-- 2) SELECT / INSERT procedures
-- 3) UPDATE procedures
-- 4) Test calls
--
-- IMPORTANT:
-- - All routines must execute in PostgreSQL without errors.
-- - Logic must be relevant to your project domain.
-- - Submit everything in this single SQL file.
-- ================================================================

-- Add your functions and procedures below this line



-- ================================================================
-- [Oleksandr] Функції та процедури для membership_plans і memberships
-- ================================================================
-- Порядок запуску: ddl.sql -> dml.sql -> цей скрипт.
--
-- Функції:
--   fn_calc_membership_end_date   - дата завершення за тарифом
--   fn_has_active_membership      - чи діє абонемент на дату
--   fn_member_total_spent         - сума витрат клієнта
-- Процедури SELECT / INSERT:
--   sp_get_member_membership_summary - зведення по клієнту
--   sp_create_membership             - оформлення абонемента
--   sp_add_membership_plan           - новий тариф
-- Процедури UPDATE:
--   sp_change_membership_status   - зміна статусу
--   sp_extend_membership          - продовження абонемента
--   sp_expire_overdue_memberships - закриття прострочених
--
-- end_date - останній день, коли абонемент діє (як у dml.sql
-- і views.sql). Абонемент закінчився, якщо end_date < дата.
-- ================================================================


-- ================================================================
-- 1) FUNCTIONS
-- ================================================================

-- ----------------------------------------------------------------
-- FUNCTION 1: fn_calc_membership_end_date
-- Дата завершення абонемента: start_date + тривалість тарифу.
-- Параметри:
--   p_plan_id    INT  - id тарифу
--   p_start_date DATE - дата початку
-- Повертає: DATE. Якщо тарифу немає - помилка, а не NULL.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fitness_center_team4.fn_calc_membership_end_date(
    p_plan_id    INT,
    p_start_date DATE
)
RETURNS DATE
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_duration_months INT;
BEGIN
    IF p_start_date IS NULL THEN
        RAISE EXCEPTION 'Дата початку абонемента не може бути NULL'
            USING ERRCODE = 'null_value_not_allowed';
    END IF;

    SELECT duration_months
    INTO v_duration_months
    FROM fitness_center_team4.membership_plans
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Тариф з plan_id = % не існує', p_plan_id
            USING ERRCODE = 'no_data_found';
    END IF;

    RETURN (p_start_date + make_interval(months => v_duration_months))::DATE;
END;
$$;


-- ----------------------------------------------------------------
-- FUNCTION 2: fn_has_active_membership
-- Чи можна пустити клієнта в зал на певну дату.
-- Параметри:
--   p_member_id  INT  - id клієнта
--   p_check_date DATE - дата перевірки (за замовчуванням сьогодні)
-- Повертає: TRUE, якщо є абонемент 'active' і дата між start_date
-- та end_date включно. Заморожений абонемент не рахується.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fitness_center_team4.fn_has_active_membership(
    p_member_id  INT,
    p_check_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM fitness_center_team4.memberships
        WHERE member_id = p_member_id
          AND status = 'active'
          AND p_check_date BETWEEN start_date AND end_date
    );
$$;


-- ----------------------------------------------------------------
-- FUNCTION 3: fn_member_total_spent
-- Скільки клієнт заплатив за всі абонементи (для програм лояльності).
-- Параметри:
--   p_member_id INT - id клієнта
-- Повертає: суму цін тарифів (0, якщо абонементів немає).
-- Рахуємо за поточною ціною тарифу, бо ціна продажу в memberships
-- не зберігається. Скасовані абонементи теж оплачені, тому входять.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fitness_center_team4.fn_member_total_spent(
    p_member_id INT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(mp.price), 0)::NUMERIC(12,2)
    FROM fitness_center_team4.memberships ms
    JOIN fitness_center_team4.membership_plans mp
        ON mp.plan_id = ms.plan_id
    WHERE ms.member_id = p_member_id;
$$;


-- ================================================================
-- 2) STORED PROCEDURES - SELECT / INSERT
-- ================================================================

-- ----------------------------------------------------------------
-- PROCEDURE 1 (SELECT): sp_get_member_membership_summary
-- Зведення по клієнту для рецепції.
-- Параметри:
--   p_member_id   INT     - id клієнта
--   p_full_name   TEXT    - INOUT: ім'я та прізвище
--   p_total_count INT     - INOUT: кількість абонементів
--   p_has_active  BOOLEAN - INOUT: чи діє абонемент сьогодні
--   p_total_spent NUMERIC - INOUT: загальна сума
-- Неіснуючий клієнт - помилка.
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_get_member_membership_summary(
    p_member_id   INT,
    INOUT p_full_name   TEXT    DEFAULT NULL,
    INOUT p_total_count INT     DEFAULT NULL,
    INOUT p_has_active  BOOLEAN DEFAULT NULL,
    INOUT p_total_spent NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT m.first_name || ' ' || m.last_name
    INTO p_full_name
    FROM fitness_center_team4.members m
    WHERE m.member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клієнта з member_id = % не існує', p_member_id
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT COUNT(*)
    INTO p_total_count
    FROM fitness_center_team4.memberships
    WHERE member_id = p_member_id;

    p_has_active  := fitness_center_team4.fn_has_active_membership(p_member_id);
    p_total_spent := fitness_center_team4.fn_member_total_spent(p_member_id);
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 2 (INSERT): sp_create_membership
-- Оформлює абонемент; end_date рахується через FUNCTION 1.
-- Параметри:
--   p_member_id     INT  - id клієнта
--   p_plan_id       INT  - id тарифу
--   p_start_date    DATE - дата початку (за замовчуванням сьогодні)
--   p_membership_id INT  - INOUT: id нового абонемента
-- Помилка, якщо: клієнта чи тарифу немає; start_date раніше
-- за реєстрацію; у клієнта вже є active/frozen абонемент на цей період.
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_create_membership(
    p_member_id  INT,
    p_plan_id    INT,
    p_start_date DATE DEFAULT CURRENT_DATE,
    INOUT p_membership_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_registration_date DATE;
    v_end_date          DATE;
BEGIN
    SELECT registration_date
    INTO v_registration_date
    FROM fitness_center_team4.members
    WHERE member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клієнта з member_id = % не існує', p_member_id
            USING ERRCODE = 'no_data_found';
    END IF;

    v_end_date := fitness_center_team4.fn_calc_membership_end_date(p_plan_id, p_start_date);

    IF p_start_date < v_registration_date THEN
        RAISE EXCEPTION 'Дата початку % раніша за дату реєстрації клієнта %',
                        p_start_date, v_registration_date
            USING ERRCODE = 'check_violation';
    END IF;

    -- Періоди перетинаються, якщо кожен починається не пізніше,
    -- ніж закінчується інший
    IF EXISTS (
        SELECT 1
        FROM fitness_center_team4.memberships
        WHERE member_id = p_member_id
          AND status IN ('active', 'frozen')
          AND start_date <= v_end_date
          AND end_date   >= p_start_date
    ) THEN
        RAISE EXCEPTION 'Клієнт % уже має чинний абонемент на цей період', p_member_id
            USING ERRCODE = 'exclusion_violation',
                  HINT = 'Продовжіть чинний абонемент через sp_extend_membership';
    END IF;

    INSERT INTO fitness_center_team4.memberships
        (member_id, plan_id, start_date, end_date, status)
    VALUES
        (p_member_id, p_plan_id, p_start_date, v_end_date, 'active')
    RETURNING membership_id INTO p_membership_id;

    RAISE NOTICE 'Створено абонемент % (% - %)', p_membership_id, p_start_date, v_end_date;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 3 (INSERT): sp_add_membership_plan
-- Додає тариф. Помилки constraints перехоплюються в EXCEPTION,
-- тому невдала вставка не зупиняє скрипт.
-- Параметри:
--   p_plan_name       VARCHAR - назва (UNIQUE)
--   p_duration_months INT     - тривалість, > 0
--   p_price           NUMERIC - ціна, >= 0
--   p_plan_id         INT     - INOUT: id нового тарифу або NULL
-- Дублікат назви чи некоректні дані - NOTICE і p_plan_id = NULL.
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_add_membership_plan(
    p_plan_name       VARCHAR,
    p_duration_months INT,
    p_price           NUMERIC,
    INOUT p_plan_id   INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN
        INSERT INTO fitness_center_team4.membership_plans
            (plan_name, duration_months, price)
        VALUES
            (p_plan_name, p_duration_months, p_price)
        RETURNING plan_id INTO p_plan_id;

        RAISE NOTICE 'Додано тариф "%" (plan_id = %)', p_plan_name, p_plan_id;
    EXCEPTION
        WHEN unique_violation THEN
            p_plan_id := NULL;
            RAISE NOTICE 'Тариф "%" уже існує - вставку скасовано', p_plan_name;
        WHEN check_violation THEN
            p_plan_id := NULL;
            RAISE NOTICE 'Некоректні дані тарифу "%": тривалість має бути > 0, ціна >= 0 (%)',
                         p_plan_name, SQLERRM;
    END;
END;
$$;


-- ================================================================
-- 3) STORED PROCEDURES - UPDATE
-- ================================================================

-- ----------------------------------------------------------------
-- PROCEDURE 4 (UPDATE): sp_change_membership_status
-- Змінює статус лише за дозволеними переходами:
--   active -> frozen, cancelled, expired
--   frozen -> active, cancelled, expired
--   expired, cancelled - кінцеві, змінювати не можна
-- Параметри:
--   p_membership_id INT               - id абонемента
--   p_new_status    membership_status - новий статус
-- Неіснуючий абонемент або заборонений перехід - помилка.
-- FOR UPDATE блокує рядок, поки триває транзакція.
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_change_membership_status(
    p_membership_id INT,
    p_new_status    fitness_center_team4.membership_status
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_status fitness_center_team4.membership_status;
BEGIN
    SELECT status
    INTO v_old_status
    FROM fitness_center_team4.memberships
    WHERE membership_id = p_membership_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Абонемента з membership_id = % не існує', p_membership_id
            USING ERRCODE = 'no_data_found';
    END IF;

    IF v_old_status = p_new_status THEN
        RAISE EXCEPTION 'Абонемент % уже має статус %', p_membership_id, p_new_status
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_old_status NOT IN ('active', 'frozen') THEN
        RAISE EXCEPTION 'Перехід % -> % заборонено для абонемента %',
                        v_old_status, p_new_status, p_membership_id
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE fitness_center_team4.memberships
    SET status = p_new_status
    WHERE membership_id = p_membership_id;

    RAISE NOTICE 'Абонемент %: % -> %', p_membership_id, v_old_status, p_new_status;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 5 (UPDATE): sp_extend_membership
-- Продовжує абонемент на N місяців (доплата, компенсація заморозки).
-- Параметри:
--   p_membership_id INT  - id абонемента
--   p_months        INT  - на скільки місяців, > 0
--   p_new_end_date  DATE - INOUT: нова дата завершення
-- Продовжити можна лише active або frozen абонемент.
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_extend_membership(
    p_membership_id INT,
    p_months        INT,
    INOUT p_new_end_date DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status fitness_center_team4.membership_status;
BEGIN
    IF p_months IS NULL OR p_months <= 0 THEN
        RAISE EXCEPTION 'Кількість місяців має бути більшою за 0 (отримано %)', p_months
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT status
    INTO v_status
    FROM fitness_center_team4.memberships
    WHERE membership_id = p_membership_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Абонемента з membership_id = % не існує', p_membership_id
            USING ERRCODE = 'no_data_found';
    END IF;

    IF v_status NOT IN ('active', 'frozen') THEN
        RAISE EXCEPTION 'Абонемент % має статус % - продовжити не можна', p_membership_id, v_status
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE fitness_center_team4.memberships
    SET end_date = (end_date + make_interval(months => p_months))::DATE
    WHERE membership_id = p_membership_id
    RETURNING end_date INTO p_new_end_date;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 6 (UPDATE): sp_expire_overdue_memberships
-- Переводить у 'expired' усі active і frozen абонементи, строк яких
-- минув (end_date < p_as_of_date). Запускається раз на день.
-- Параметри:
--   p_as_of_date    DATE - дата перевірки (за замовчуванням сьогодні)
--   p_updated_count INT  - INOUT: скільки абонементів закрито
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fitness_center_team4.sp_expire_overdue_memberships(
    p_as_of_date DATE DEFAULT CURRENT_DATE,
    INOUT p_updated_count INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE fitness_center_team4.memberships
    SET status = 'expired'
    WHERE status IN ('active', 'frozen')
      AND end_date < p_as_of_date;

    GET DIAGNOSTICS p_updated_count = ROW_COUNT;

    RAISE NOTICE 'Переведено в expired: % абонемент(ів)', p_updated_count;
END;
$$;


-- ================================================================
-- 4) TEST CALLS
-- ================================================================
-- Клієнтів і тарифи шукаємо за email та plan_name, як у dml.sql.
-- Тести, що змінюють дані, - у BEGIN ... ROLLBACK.
-- Тести з помилками - у DO-блоках з EXCEPTION, щоб скрипт
-- виконувався до кінця.
-- В аргументах CALL не можна писати підзапит, тому id шукаємо
-- в DO-блоці.
-- ================================================================


-- ---------- FUNCTION 1: fn_calc_membership_end_date ----------
-- Очікується: 2027-01-12
SELECT fitness_center_team4.fn_calc_membership_end_date(
    (SELECT plan_id FROM fitness_center_team4.membership_plans WHERE plan_name = 'Квартальний'),
    '2026-10-12'
) AS quarterly_end_date;

-- 31 січня + 1 місяць. Очікується: 2027-02-28
SELECT fitness_center_team4.fn_calc_membership_end_date(
    (SELECT plan_id FROM fitness_center_team4.membership_plans WHERE plan_name = 'Місячний'),
    '2027-01-31'
) AS month_end_edge_case;

-- Помилка: неіснуючий тариф
DO $$
BEGIN
    PERFORM fitness_center_team4.fn_calc_membership_end_date(99999, CURRENT_DATE);
EXCEPTION WHEN no_data_found THEN
    RAISE NOTICE 'Очікувана помилка: %', SQLERRM;
END;
$$;


-- ---------- FUNCTION 2: fn_has_active_membership ----------
-- Юлія Руденко: абонемент з 2026-10-01 по 2026-11-01.
-- Очікується: TRUE, TRUE (останній день), FALSE
SELECT
    fitness_center_team4.fn_has_active_membership(m.member_id, '2026-10-15') AS active_mid_october,
    fitness_center_team4.fn_has_active_membership(m.member_id, '2026-11-01') AS active_on_end_date,
    fitness_center_team4.fn_has_active_membership(m.member_id, '2026-11-02') AS active_after_end
FROM fitness_center_team4.members m
WHERE m.email = 'y.rudenko@domain.com';

-- Василь Мороз (без абонементів) і неіснуючий клієнт. Очікується: FALSE, FALSE
SELECT
    fitness_center_team4.fn_has_active_membership(
        (SELECT member_id FROM fitness_center_team4.members WHERE email = 'v.moroz@example.org')
    ) AS moroz_active,
    fitness_center_team4.fn_has_active_membership(99999) AS unknown_member_active;

-- Хто з клієнтів може сьогодні пройти в зал
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    fitness_center_team4.fn_has_active_membership(m.member_id) AS can_enter_today
FROM fitness_center_team4.members m
ORDER BY m.member_id;


-- ---------- FUNCTION 3: fn_member_total_spent ----------
-- Очікується: Лисенко 2400.00 (0 + 2400), Мороз 0.00
SELECT
    m.email,
    fitness_center_team4.fn_member_total_spent(m.member_id) AS total_spent
FROM fitness_center_team4.members m
WHERE m.email IN ('v.lysenko@test-mail.org', 'v.moroz@example.org');

-- Топ-3 клієнтів за витратами
SELECT
    m.first_name,
    m.last_name,
    fitness_center_team4.fn_member_total_spent(m.member_id) AS total_spent
FROM fitness_center_team4.members m
ORDER BY total_spent DESC, m.member_id
LIMIT 3;


-- ---------- PROCEDURE 1: sp_get_member_membership_summary ----------
-- Очікується: Вікторія Лисенко, 2 абонементи, не діє, 2400.00
DO $$
DECLARE
    v_member_id INT;
    v_name TEXT; v_cnt INT; v_active BOOLEAN; v_spent NUMERIC;
BEGIN
    SELECT member_id INTO v_member_id
    FROM fitness_center_team4.members WHERE email = 'v.lysenko@test-mail.org';

    CALL fitness_center_team4.sp_get_member_membership_summary(v_member_id, v_name, v_cnt, v_active, v_spent);

    RAISE NOTICE 'Клієнт: %, абонементів: %, діє зараз: %, витрачено: % грн',
                 v_name, v_cnt, v_active, v_spent;
END;
$$;

-- Помилка: неіснуючий клієнт
DO $$
DECLARE
    v_name TEXT; v_cnt INT; v_active BOOLEAN; v_spent NUMERIC;
BEGIN
    CALL fitness_center_team4.sp_get_member_membership_summary(99999, v_name, v_cnt, v_active, v_spent);
EXCEPTION WHEN no_data_found THEN
    RAISE NOTICE 'Очікувана помилка: %', SQLERRM;
END;
$$;


-- ---------- PROCEDURE 2: sp_create_membership ----------
BEGIN;

-- Оформлюємо квартальний абонемент Василю Морозу
DO $$
DECLARE
    v_member_id     INT;
    v_plan_id       INT;
    v_membership_id INT;
BEGIN
    SELECT member_id INTO v_member_id
    FROM fitness_center_team4.members WHERE email = 'v.moroz@example.org';
    SELECT plan_id INTO v_plan_id
    FROM fitness_center_team4.membership_plans WHERE plan_name = 'Квартальний';

    CALL fitness_center_team4.sp_create_membership(v_member_id, v_plan_id, '2026-10-12', v_membership_id);
    RAISE NOTICE 'Повернутий membership_id = %', v_membership_id;
END;
$$;

-- Очікується: новий рядок з end_date 2027-01-12
SELECT ms.membership_id, ms.start_date, ms.end_date, ms.status
FROM fitness_center_team4.memberships ms
JOIN fitness_center_team4.members m ON m.member_id = ms.member_id
WHERE m.email = 'v.moroz@example.org';

-- Помилка: другий абонемент на період, що перетинається з першим
DO $$
DECLARE
    v_member_id INT;
    v_plan_id   INT;
    v_id        INT;
BEGIN
    SELECT member_id INTO v_member_id
    FROM fitness_center_team4.members WHERE email = 'v.moroz@example.org';
    SELECT plan_id INTO v_plan_id
    FROM fitness_center_team4.membership_plans WHERE plan_name = 'Місячний';

    CALL fitness_center_team4.sp_create_membership(v_member_id, v_plan_id, '2026-11-01', v_id);
EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'Очікувана помилка: %', SQLERRM;
END;
$$;

ROLLBACK;

-- Помилки: неіснуючий клієнт, неіснуючий тариф,
-- дата початку раніша за реєстрацію
DO $$
DECLARE
    v_member_id INT;
    v_plan_id   INT;
    v_id        INT;
BEGIN
    SELECT member_id INTO v_member_id
    FROM fitness_center_team4.members WHERE email = 'v.moroz@example.org';
    SELECT plan_id INTO v_plan_id
    FROM fitness_center_team4.membership_plans WHERE plan_name = 'Місячний';

    BEGIN
        CALL fitness_center_team4.sp_create_membership(99999, v_plan_id, CURRENT_DATE, v_id);
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Очікувана помилка 1: %', SQLERRM;
    END;

    BEGIN
        CALL fitness_center_team4.sp_create_membership(v_member_id, 99999, CURRENT_DATE, v_id);
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Очікувана помилка 2: %', SQLERRM;
    END;

    BEGIN
        CALL fitness_center_team4.sp_create_membership(v_member_id, v_plan_id, '2000-01-01', v_id);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'Очікувана помилка 3: %', SQLERRM;
    END;
END;
$$;


-- ---------- PROCEDURE 3: sp_add_membership_plan ----------
BEGIN;

-- Успіх: повертається plan_id
CALL fitness_center_team4.sp_add_membership_plan('Вечірній місячний', 1, 750.00, NULL);

-- Дублікат назви: NOTICE, plan_id = NULL
CALL fitness_center_team4.sp_add_membership_plan('Місячний', 1, 1000.00, NULL);

-- Від'ємна ціна: NOTICE, plan_id = NULL
CALL fitness_center_team4.sp_add_membership_plan('Помилковий', 1, -100.00, NULL);

-- Очікується: лише 'Вечірній місячний'
SELECT plan_id, plan_name, duration_months, price
FROM fitness_center_team4.membership_plans
WHERE plan_name IN ('Вечірній місячний', 'Помилковий');

ROLLBACK;


-- ---------- PROCEDURE 4: sp_change_membership_status ----------
BEGIN;

-- Заморожуємо абонемент Юлії Руденко
DO $$
DECLARE
    v_membership_id INT;
BEGIN
    SELECT ms.membership_id INTO v_membership_id
    FROM fitness_center_team4.memberships ms
    JOIN fitness_center_team4.members m ON m.member_id = ms.member_id
    WHERE m.email = 'y.rudenko@domain.com' AND ms.status = 'active';

    CALL fitness_center_team4.sp_change_membership_status(v_membership_id, 'frozen');
END;
$$;

-- Очікується: FALSE (заморожений абонемент не діє)
SELECT fitness_center_team4.fn_has_active_membership(
    (SELECT member_id FROM fitness_center_team4.members WHERE email = 'y.rudenko@domain.com'),
    '2026-10-15'
) AS active_after_freeze;

ROLLBACK;

-- Помилки: cancelled -> active і неіснуючий абонемент
DO $$
DECLARE
    v_membership_id INT;
BEGIN
    SELECT ms.membership_id INTO v_membership_id
    FROM fitness_center_team4.memberships ms
    JOIN fitness_center_team4.members m ON m.member_id = ms.member_id
    WHERE m.email = 'v.lysenko@test-mail.org' AND ms.status = 'cancelled';

    BEGIN
        CALL fitness_center_team4.sp_change_membership_status(v_membership_id, 'active');
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'Очікувана помилка 1: %', SQLERRM;
    END;

    BEGIN
        CALL fitness_center_team4.sp_change_membership_status(99999, 'frozen');
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Очікувана помилка 2: %', SQLERRM;
    END;
END;
$$;


-- ---------- PROCEDURE 5: sp_extend_membership ----------
BEGIN;

-- Продовжуємо абонемент Юлії Руденко на 2 місяці.
-- Очікується: 2026-11-01 -> 2027-01-01
DO $$
DECLARE
    v_membership_id INT;
    v_new_end       DATE;
BEGIN
    SELECT ms.membership_id INTO v_membership_id
    FROM fitness_center_team4.memberships ms
    JOIN fitness_center_team4.members m ON m.member_id = ms.member_id
    WHERE m.email = 'y.rudenko@domain.com' AND ms.status = 'active';

    CALL fitness_center_team4.sp_extend_membership(v_membership_id, 2, v_new_end);
    RAISE NOTICE 'Абонемент % продовжено до %', v_membership_id, v_new_end;
END;
$$;

ROLLBACK;

-- Помилки: 0 місяців і продовження expired-абонемента
DO $$
DECLARE
    v_membership_id INT;
    v_end           DATE;
BEGIN
    SELECT ms.membership_id INTO v_membership_id
    FROM fitness_center_team4.memberships ms
    JOIN fitness_center_team4.members m ON m.member_id = ms.member_id
    WHERE m.email = 'v.lysenko@test-mail.org' AND ms.status = 'expired';

    BEGIN
        CALL fitness_center_team4.sp_extend_membership(v_membership_id, 0, v_end);
    EXCEPTION WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Очікувана помилка 1: %', SQLERRM;
    END;

    BEGIN
        CALL fitness_center_team4.sp_extend_membership(v_membership_id, 1, v_end);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'Очікувана помилка 2: %', SQLERRM;
    END;
END;
$$;


-- ---------- PROCEDURE 6: sp_expire_overdue_memberships ----------
BEGIN;

-- Що має закритися станом на 2026-12-01
SELECT membership_id, member_id, end_date, status
FROM fitness_center_team4.memberships
WHERE status IN ('active', 'frozen')
  AND end_date < DATE '2026-12-01';

CALL fitness_center_team4.sp_expire_overdue_memberships('2026-12-01', NULL);

-- Повторний виклик: 0
CALL fitness_center_team4.sp_expire_overdue_memberships('2026-12-01', NULL);

ROLLBACK;


-- ================================================================
-- Optional cleanup
-- ================================================================
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_expire_overdue_memberships(DATE, INT);
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_extend_membership(INT, INT, DATE);
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_change_membership_status(INT, fitness_center_team4.membership_status);
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_add_membership_plan(VARCHAR, INT, NUMERIC, INT);
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_create_membership(INT, INT, DATE, INT);
-- DROP PROCEDURE IF EXISTS fitness_center_team4.sp_get_member_membership_summary(INT, TEXT, INT, BOOLEAN, NUMERIC);
-- DROP FUNCTION  IF EXISTS fitness_center_team4.fn_member_total_spent(INT);
-- DROP FUNCTION  IF EXISTS fitness_center_team4.fn_has_active_membership(INT, DATE);
-- DROP FUNCTION  IF EXISTS fitness_center_team4.fn_calc_membership_end_date(INT, DATE);
