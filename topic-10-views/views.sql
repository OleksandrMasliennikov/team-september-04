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


-- =====================================================
-- Oleksandr - Views for Memberships and Membership Plans
-- =====================================================
-- Таблиці: membership_plans (тарифи) та memberships (абонементи).
-- Ці views відповідають на щоденні питання адміністратора
-- фітнес-центру: що ми продаємо, у кого абонемент діє,
-- кому скоро продовжувати, які тарифи приносять дохід.
-- JOIN members + memberships + membership_plans уже є у
-- view_member_memberships (Boris, VIEW 8), тому тут не дублюється.
-- =====================================================


-- =====================================================
-- VIEW 13: Прайс-лист тарифів
-- Тип: Horizontal View
-- Призначення:
-- Показує лише стовпці, потрібні клієнту: назву плану,
-- тривалість і ціну. Технічний plan_id приховано.
-- Зв'язок з дизайном: membership_plans - довідник тарифів,
-- цей view - його "публічна" частина для сайту чи рецепції.
-- =====================================================

CREATE VIEW fitness_center_team4.view_plan_price_list AS
SELECT
    plan_name,
    duration_months,
    price
FROM fitness_center_team4.membership_plans;


-- =====================================================
-- VIEW 14: Діючі абонементи
-- Тип: Vertical View
-- Призначення:
-- Залишає лише ті рядки memberships, які зараз діють:
-- статус 'active' і строк ще не минув. Усі стовпці таблиці
-- збережені.
-- Зв'язок з дизайном: status (ENUM membership_status) та
-- end_date разом визначають, чи може клієнт зараз тренуватися.
-- =====================================================

CREATE VIEW fitness_center_team4.view_active_memberships AS
SELECT
    membership_id,
    member_id,
    plan_id,
    start_date,
    end_date,
    status
FROM fitness_center_team4.memberships
WHERE status = 'active'
  AND end_date >= CURRENT_DATE;


-- =====================================================
-- VIEW 15: Абонементи, що закінчуються протягом 14 днів
-- Тип: Mixed View
-- Призначення:
-- Обмежує і стовпці (лише id, дата закінчення та кількість
-- днів, що лишилися), і рядки (лише активні абонементи, які
-- закінчуються в найближчі 14 днів).
-- Використовується для нагадувань клієнтам про продовження.
-- =====================================================

CREATE VIEW fitness_center_team4.view_expiring_memberships AS
SELECT
    membership_id,
    member_id,
    end_date,
    end_date - CURRENT_DATE AS days_left
FROM fitness_center_team4.memberships
WHERE status = 'active'
  AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 14;


-- =====================================================
-- VIEW 16: Продажі та дохід за кожним тарифом
-- Тип: JOIN View (з агрегацією)
-- Призначення:
-- Поєднує membership_plans і memberships, щоб показати,
-- скільки абонементів кожного плану продано і на яку суму.
-- LEFT JOIN залишає у звіті й тарифи без жодного продажу
-- (для них sold_count = 0, revenue = 0).
-- Обмеження: дохід рахується за поточною ціною плану,
-- бо в memberships ціна продажу не зберігається.
-- =====================================================

CREATE VIEW fitness_center_team4.view_plan_sales_summary AS
SELECT
    mp.plan_id,
    mp.plan_name,
    mp.price,
    COUNT(ms.membership_id)                 AS sold_count,
    COUNT(ms.membership_id) * mp.price      AS revenue
FROM fitness_center_team4.membership_plans mp
LEFT JOIN fitness_center_team4.memberships ms
    ON ms.plan_id = mp.plan_id
GROUP BY
    mp.plan_id,
    mp.plan_name,
    mp.price;


-- =====================================================
-- VIEW 17: Постійні клієнти (купували абонемент більше одного разу)
-- Тип: View with Subquery
-- Призначення:
-- Підзапит знаходить member_id, які мають 2+ абонементи,
-- а зовнішній запит показує цих клієнтів із таблиці members.
-- Може використовуватися для програм лояльності та знижок
-- на продовження.
-- Зв'язок з дизайном: демонструє зв'язок one-to-many
-- members -> memberships.
-- =====================================================

CREATE VIEW fitness_center_team4.view_returning_members AS
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    m.email
FROM fitness_center_team4.members m
WHERE m.member_id IN (
    SELECT member_id
    FROM fitness_center_team4.memberships
    GROUP BY member_id
    HAVING COUNT(*) > 1
);


-- =====================================================
-- VIEW 18: Поточні та минулі абонементи
-- Тип: UNION View
-- Призначення:
-- Об'єднує два набори абонементів в одну історію з
-- позначкою періоду:
--   'Поточний' - active та frozen (клієнт ще користується);
--   'Минулий'  - expired та cancelled (абонемент завершено).
-- Обидва SELECT мають однакову кількість і типи стовпців,
-- як цього вимагає UNION. Дублікатів між частинами не буде,
-- бо умови за status не перетинаються.
-- Тому тут дав би той самий результат і UNION ALL (він швидший,
-- бо не шукає дублікатів); UNION залишено як основну форму з завдання.
-- =====================================================

CREATE VIEW fitness_center_team4.view_membership_history AS
SELECT
    membership_id,
    member_id,
    plan_id,
    start_date,
    end_date,
    status,
    'Поточний' AS period
FROM fitness_center_team4.memberships
WHERE status IN ('active', 'frozen')

UNION

SELECT
    membership_id,
    member_id,
    plan_id,
    start_date,
    end_date,
    status,
    'Минулий' AS period
FROM fitness_center_team4.memberships
WHERE status IN ('expired', 'cancelled');


-- =====================================================
-- VIEW 19: Кількість діючих абонементів за тарифами
-- Тип: View Based on Another View
-- Призначення:
-- Підсумковий звіт, побудований на view_active_memberships
-- (VIEW 14): показує, скільки діючих абонементів має кожен
-- тариф. Якщо зміниться правило "діючого" абонемента,
-- його достатньо змінити в одному місці - у VIEW 14.
-- =====================================================

CREATE VIEW fitness_center_team4.view_active_memberships_by_plan AS
SELECT
    mp.plan_name,
    COUNT(*) AS active_count
FROM fitness_center_team4.view_active_memberships am
JOIN fitness_center_team4.membership_plans mp
    ON mp.plan_id = am.plan_id
GROUP BY
    mp.plan_name;


-- =====================================================
-- VIEW 20: Редагування лише активних абонементів
-- Тип: Updatable View with CHECK OPTION
-- Призначення:
-- Через цей view адміністратор може продовжити (змінити
-- end_date) лише активний абонемент.
-- WITH CHECK OPTION не дозволяє через view:
--   - додати абонемент з іншим статусом, ніж 'active';
--   - змінити рядок так, щоб він перестав бути 'active'.
-- Заморозка чи скасування робляться окремою операцією
-- безпосередньо в таблиці memberships.
-- View оновлюваний, бо побудований на одній таблиці без
-- JOIN, GROUP BY, DISTINCT та агрегатів.
-- Відмінність від VIEW 14: тут немає умови end_date >= CURRENT_DATE.
-- Це навмисно: адміністратор має змогу продовжити й абонемент,
-- строк якого вже минув, але який ще не переведено в 'expired'.
-- Крім того, з умовою за датою demo-UPDATE нижче перестав би
-- працювати після закінчення абонемента Юлії Руденко.
-- =====================================================

CREATE VIEW fitness_center_team4.view_editable_active_memberships AS
SELECT
    membership_id,
    member_id,
    plan_id,
    start_date,
    end_date,
    status
FROM fitness_center_team4.memberships
WHERE status = 'active'
WITH CHECK OPTION;


-- =====================================================
-- [Oleksandr] Demo SELECT для кожного view
-- =====================================================

SELECT * FROM fitness_center_team4.view_plan_price_list ORDER BY price;
SELECT * FROM fitness_center_team4.view_active_memberships ORDER BY end_date;
SELECT * FROM fitness_center_team4.view_expiring_memberships ORDER BY days_left;
SELECT * FROM fitness_center_team4.view_plan_sales_summary ORDER BY revenue DESC;
SELECT * FROM fitness_center_team4.view_returning_members ORDER BY last_name;
SELECT * FROM fitness_center_team4.view_membership_history ORDER BY period, membership_id;
SELECT * FROM fitness_center_team4.view_active_memberships_by_plan ORDER BY active_count DESC;


-- =====================================================
-- [Oleksandr] Demo CHECK OPTION (VIEW 20)
-- =====================================================
-- Дозволено: продовжити активний абонемент на місяць.
-- Обгорнуто в транзакцію з ROLLBACK, щоб демо не змінювало дані.
BEGIN;

UPDATE fitness_center_team4.view_editable_active_memberships
SET end_date = end_date + INTERVAL '1 month'
WHERE member_id = (SELECT member_id FROM fitness_center_team4.members
                   WHERE email = 'y.rudenko@domain.com')
RETURNING membership_id, end_date, status;

ROLLBACK;

-- Заборонено: змінити статус так, що рядок зникне з view.
-- Очікується: new row violates check option for view "view_editable_active_memberships"
-- UPDATE fitness_center_team4.view_editable_active_memberships
-- SET status = 'cancelled'
-- WHERE member_id = (SELECT member_id FROM fitness_center_team4.members
--                    WHERE email = 'y.rudenko@domain.com');

-- Заборонено: додати через view абонемент зі статусом не 'active'.
-- Очікується: new row violates check option for view "view_editable_active_memberships"
-- INSERT INTO fitness_center_team4.view_editable_active_memberships
--   (member_id, plan_id, start_date, end_date, status)
-- VALUES (
--   (SELECT member_id FROM fitness_center_team4.members WHERE email = 'v.moroz@example.org'),
--   (SELECT plan_id FROM fitness_center_team4.membership_plans WHERE plan_name = 'Місячний'),
--   '2026-10-01', '2026-11-01', 'frozen');
