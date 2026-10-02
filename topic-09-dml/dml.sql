-- ================================================================
-- SQL DML TEMPLATE (TOPIC 09)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) INSERT scripts for all required tables in your database.
-- 2) At least 10 records per table with meaningful, realistic values.
-- 3) UPDATE / DELETE scripts where they are relevant to business logic.
-- 4) If UPDATE / DELETE are not relevant for a table, add a short note
--    in documentation explaining why.
-- 5) Comments by section so the script is easy to read and run.
--
-- SCRIPT GOALS:
-- - Populate the database with usable test data.
-- - Validate constraints through realistic DML scenarios.
-- - Support the core functionality of your application.
--
-- RECOMMENDED ORDER:
-- 1) Reference data (lookups/dictionaries)
-- 2) Core entities
-- 3) Transactional data
-- 4) Optional UPDATE / DELETE checks
--
-- IMPORTANT:
-- - Use anonymized or privacy-safe sample data where possible.
-- - The script must execute in PostgreSQL.
-- - Submit this as one SQL file.
-- ================================================================

-- Add your DML below this line

-- ================================================
-- [Boris] Таблиця members: вставка, невалідні INSERT, UPDATE, DELETE
-- ================================================

-- -- Вставка валідних даних у таблицю  members (12 записів)
INSERT INTO fitness_center_team4.members (first_name, last_name, email, phone, birth_date, registration_date)
VALUES
  -- Записи з повними даними
  ('Олександр', 'Коваленко', 'o.kovalenko@example.com',   '+380501234567', '1990-05-14', '2022-01-15 10:30:00'),
  ('Анна',      'Шевченко',  'a.shevchenko@example.org',  '+380672345678', '1985-11-22', '2021-08-01 14:15:00'),
  ('Максим',    'Бондаренко','m.bondarenko@example.net',  '+380633456789', '1998-03-30', '2023-03-10 09:00:00'),
  ('Марія',     'Мельник',   'm.melnyk@example.com',      '+380954567890', '2001-07-08', '2023-11-05 18:45:00'),
  ('Дмитро',    'Ткаченко',  'd.tkachenko@domain.com',    '+380975678901', '1978-12-19', '2020-05-20 11:20:00'),
  ('Олена',     'Кравченко', 'o.kravchenko@domain.org',   '+380506789012', '1995-09-02', '2022-09-12 16:00:00'),
  ('Андрій',    'Коваль',    'a.koval@test-mail.com',     '+380687890123', '1992-04-17', '2021-12-01 08:30:00'),

  -- Записи з NULL значеннями (відсутній phone)
  ('Ірина',     'Бойко',     'i.boyko@example.com',       NULL,           '1989-01-25', '2022-04-18 12:10:00'),
  ('Сергій',    'Поліщук',   's.polishchuk@domain.net',   NULL,           '1996-06-11', '2023-01-22 15:40:00'),

  -- Записи з NULL значеннями (відсутній birth_date)
  ('Вікторія',  'Лисенко',   'v.lysenko@test-mail.org',   '+380939012345', NULL,         '2023-06-30 13:00:00'),

  -- Записи з NULL значеннями у двох optional-полях (без phone та без birth_date)
  ('Василь',    'Мороз',     'v.moroz@example.org',       NULL,           NULL,         '2023-09-01 10:00:00'),
  ('Юлія',      'Руденко',   'y.rudenko@domain.com',      NULL,           NULL,         '2024-02-14 17:25:00');



-- ================================================
-- [Boris] Невалідні INSERT (кожен має давати помилку)
-- Запускати по одному, прибравши -- перед рядками
-- ================================================

-- 1. email: після @ немає домену
-- Очікується: violates check constraint "chk_members_email_format"
-- INSERT INTO fitness_center_team4.members
--   (first_name, last_name, email, phone, birth_date, registration_date)
-- VALUES
--   ('Олександр', 'Коваленко', 'o.kovalenko@', '+380501234567', '1990-05-14', '2022-01-15');

-- 2. email: немає символу @
-- Очікується: violates check constraint "chk_members_email_format"
-- INSERT INTO fitness_center_team4.members
--   (first_name, last_name, email, phone, birth_date, registration_date)
-- VALUES
--   ('Олександр', 'Коваленко', 'o.kovalenko.example.com', '+380501234567', '1990-05-14', '2022-01-15');

-- 3. registration_date раніше за birth_date
-- Очікується: violates check constraint "chk_members_reg_date_after_birth"
-- INSERT INTO fitness_center_team4.members
--   (first_name, last_name, email, phone, birth_date, registration_date)
-- VALUES
--   ('Тест', 'Раніше', 'test.earlier@example.com', '+380501111111', '2000-01-01', '1999-12-31');

-- 4. Дублікат email: точно такий самий
-- Очікується: duplicate key value violates unique constraint "members_email_key"
-- INSERT INTO fitness_center_team4.members
--   (first_name, last_name, email, phone, birth_date, registration_date)
-- VALUES
--   ('Олександр', 'Коваленко', 'o.kovalenko@example.com', '+380501234567', '1990-05-14', '2022-01-15');

-- 5. Дублікат email: відрізняється лише регістром (CITEXT)
-- Очікується: duplicate key value violates unique constraint "members_email_key"
-- INSERT INTO fitness_center_team4.members
--   (first_name, last_name, email, phone, birth_date, registration_date)
-- VALUES
--   ('Олександр', 'Коваленко', 'O.kovalenko@example.com', '+380501234567', '1990-05-14', '2022-01-15');


-- ================================================
-- [Boris] UPDATE: оновлення даних учасників
-- ================================================

-- Змінити телефон Олександра Коваленка
-- Умова за іменем, прізвищем і email, щоб змінився лише один рядок
UPDATE fitness_center_team4.members
SET phone = '+380972345111'
WHERE first_name = 'Олександр'
  AND last_name = 'Коваленко'
  AND email = 'o.kovalenko@example.com';

-- Змінити прізвище Анни Шевченко на Винник
-- Умова за телефоном і email, щоб не зачепити інших учасників
UPDATE fitness_center_team4.members
SET last_name = 'Винник'
WHERE phone = '+380672345678'
  AND email = 'a.shevchenko@example.org';


-- ================================================
-- [Boris] DELETE: видалення тестового учасника
-- ================================================

-- Спочатку вставляємо учасника, який не матиме зв'язків
-- з іншими таблицями (memberships, attendance)
INSERT INTO fitness_center_team4.members
  (first_name, last_name, email, phone, birth_date, registration_date)
VALUES
  ('Олег', 'Видалення', 'o.test@gmail.com', '+380531234222', '1985-12-12', '2021-12-01');

-- Видаляємо його за email
-- RETURNING показує, кого саме видалено
DELETE FROM fitness_center_team4.members
WHERE email = 'o.test@gmail.com'
RETURNING member_id, first_name, last_name;

-- Перевірка: має повернути 0 рядків
SELECT * FROM fitness_center_team4.members
WHERE email = 'o.test@gmail.com';


