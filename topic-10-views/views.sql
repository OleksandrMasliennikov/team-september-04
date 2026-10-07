-- ================================================================
-- SQL VIEWS TEMPLATE (TOPIC 10)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) CREATE VIEW scripts for required view types:
--    - Horizontal view (select specific columns)
--    - Vertical view (filter specific rows)
--    - Mixed view (columns + row filters)
--    - Join-based view (multiple tables)
--    - Subquery-based view
--    - UNION-based view
--    - View based on another view
--    - Updatable view with WITH CHECK OPTION
--
-- 2) Comments before each view explaining:
--    - Purpose of the view
--    - How it supports your project design
--
-- 3) Optional demo SELECT statements to show view output.
--
-- RECOMMENDED ORDER:
-- 1) Simple views (horizontal / vertical / mixed)
-- 2) Join and subquery views
-- 3) UNION and layered views
-- 4) CHECK OPTION view
--
-- IMPORTANT:
-- - Script must execute in PostgreSQL without errors.
-- - Keep naming consistent and readable.
-- - Submit all views in this single SQL file.
-- ================================================================

-- Add your CREATE VIEW statements below this line

-- =====================================================
-- Boris - Views for Members and Member-Related Data
-- =====================================================

-- =====================================================
-- VIEW 1: Контактні дані учасників клубу
-- Тип: Horizontal View
-- Призначення:
-- Показує лише необхідні контактні дані учасників:
-- ім'я, прізвище та номер телефону.
-- Використовується для швидкого доступу до контактної
-- інформації без відображення інших персональних даних.
-- =====================================================

CREATE VIEW fitness_center_team4.full_name_phone AS
SELECT
    last_name,
    first_name,
    phone
FROM fitness_center_team4.members;


-- =====================================================
-- VIEW 2: Список контактів учасників
-- Тип: Mixed View
-- Призначення:
-- Формує повне ім'я учасника та відображає його
-- контактні дані (телефон і email).
-- Полегшує використання інформації у звітах
-- та адміністративних операціях.
-- =====================================================

CREATE VIEW fitness_center_team4.view_member_contact_list AS
SELECT
    last_name || ' ' || first_name AS full_name,
    phone,
    email
FROM fitness_center_team4.members;


-- =====================================================
-- VIEW 3: Статистика доменів електронної пошти
-- Тип: Aggregation View
-- Призначення:
-- Аналізує домени email-адрес користувачів
-- та показує, скільки учасників використовують
-- кожен домен.
-- Може використовуватися для статистичного аналізу
-- клієнтської бази.
-- =====================================================

CREATE VIEW fitness_center_team4.view_member_email_domains AS
SELECT
    SUBSTRING(email FROM POSITION('@' IN email) + 1) AS email_domain,
    COUNT(*) AS domain_count
FROM fitness_center_team4.members
WHERE email IS NOT NULL
GROUP BY
    SUBSTRING(email FROM POSITION('@' IN email) + 1);


-- =====================================================
-- VIEW 4: Тривалість членства в клубі
-- Тип: Vertical View
-- Призначення:
-- Показує, скільки днів та років кожен учасник
-- перебуває у фітнес-клубі.
-- Може використовуватися для програм лояльності,
-- аналізу активності клієнтів та маркетингових кампаній.
-- =====================================================

CREATE VIEW fitness_center_team4.view_members_loyalty_duration AS
SELECT
    member_id,
    first_name,
    last_name,
    registration_date,
    CURRENT_DATE - registration_date AS membership_days,
    EXTRACT(
        YEAR
        FROM AGE(
            CURRENT_DATE::TIMESTAMPTZ,
            registration_date::TIMESTAMPTZ
        )
    ) AS years_in_club
FROM fitness_center_team4.members;


-- =====================================================
-- VIEW 5: Іменинники поточного місяця
-- Тип: Vertical View
-- Призначення:
-- Відображає лише тих учасників клубу,
-- день народження яких припадає на поточний місяць.
-- Може використовуватися для автоматичних привітань
-- або спеціальних акцій для клієнтів.
-- =====================================================

CREATE VIEW fitness_center_team4.view_monthly_birthday_members AS
SELECT
    member_id,
    last_name || ' ' || first_name AS full_name,
    birth_date
FROM fitness_center_team4.members
WHERE EXTRACT(MONTH FROM birth_date) =
      EXTRACT(MONTH FROM CURRENT_DATE);


-- =====================================================
-- VIEW 6: Анонімізовані контактні дані учасників
-- Тип: Mixed View
-- Призначення:
-- Приховує частину номера телефону користувача
-- для захисту персональних даних.
-- Використовується у звітах, де повний номер
-- телефону не потрібний.
-- =====================================================

CREATE VIEW fitness_center_team4.view_monthly_members_anonymized AS
SELECT
    member_id,
    first_name,
    last_name,
    SUBSTRING(phone, 1, 4) || '*********' AS masked_phone
FROM fitness_center_team4.members
WHERE phone IS NOT NULL;


-- =====================================================
-- VIEW 7: Потенційні члени однієї родини
-- Тип: Aggregation View
-- Призначення:
-- Показує прізвища, які зустрічаються у базі
-- щонайменше двічі.
-- Може допомогти визначити потенційно пов'язаних
-- членів родини та використовуватися для сімейних
-- абонементів або спеціальних програм.
-- =====================================================

CREATE VIEW fitness_center_team4.view_potential_family_members AS
SELECT
    last_name,
    COUNT(*) AS family_count
FROM fitness_center_team4.members
GROUP BY
    last_name
HAVING COUNT(*) >= 2;


-- =====================================================
-- VIEW 8: Учасники та їх абонементи
-- Тип: JOIN View
-- Призначення:
-- Відображає інформацію про учасників клубу та їх
-- абонементи шляхом об'єднання таблиць members,
-- memberships та membership_plans.
-- =====================================================

CREATE VIEW fitness_center_team4.view_member_memberships AS
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    mp.plan_name,
    ms.start_date,
    ms.end_date,
    ms.status
FROM fitness_center_team4.members m
JOIN fitness_center_team4.memberships ms
    ON m.member_id = ms.member_id
JOIN fitness_center_team4.membership_plans mp
    ON ms.plan_id = mp.plan_id;


-- =====================================================
-- VIEW 9: Учасники зі стажем вище середнього
-- Тип: View with Subquery
-- Призначення:
-- Відображає учасників, тривалість членства яких
-- перевищує середню тривалість членства по клубу.
-- Використовує підзапит для обчислення середнього значення.
-- =====================================================

CREATE VIEW fitness_center_team4.view_members_above_average_loyalty AS
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    m.registration_date,
    CURRENT_DATE - m.registration_date AS membership_days
FROM fitness_center_team4.members m
WHERE CURRENT_DATE - m.registration_date >
(
    SELECT AVG(CURRENT_DATE - registration_date)
    FROM fitness_center_team4.members
);


-- =====================================================
-- VIEW 10: Усі особи фітнес-клубу
-- Тип: UNION View
-- Призначення:
-- Об'єднує інформацію про учасників клубу та тренерів
-- в єдиний список контактних осіб за допомогою UNION.
-- =====================================================

CREATE VIEW fitness_center_team4.view_all_people AS
SELECT
    m.first_name,
    m.last_name,
    m.email,
    'Member' AS person_type
FROM fitness_center_team4.members m

UNION

SELECT
    t.first_name,
    t.last_name,
    t.email,
    'Trainer' AS person_type
FROM fitness_center_team4.trainers t;


-- =====================================================
-- VIEW 11: Контакти учасників з електронною поштою
-- Тип: View Based on Another View
-- Призначення:
-- Створене на основі view_member_contact_list.
-- Відображає лише тих учасників, у яких вказана
-- адреса електронної пошти.
-- =====================================================

CREATE VIEW fitness_center_team4.view_member_email_contacts AS
SELECT
    full_name,
    email
FROM fitness_center_team4.view_member_contact_list
WHERE email IS NOT NULL;


-- =====================================================
-- VIEW 12: Учасники з вказаною електронною поштою
-- Тип: View with CHECK OPTION
-- Призначення:
-- Відображає лише учасників, які мають email.
-- CHECK OPTION гарантує, що через дане представлення
-- не можна додати або змінити запис так, щоб він
-- перестав відповідати умові відбору.
-- =====================================================

CREATE VIEW fitness_center_team4.view_members_with_email AS
SELECT
    member_id,
    first_name,
    last_name,
    email
FROM fitness_center_team4.members
WHERE email IS NOT NULL
WITH CHECK OPTION;

