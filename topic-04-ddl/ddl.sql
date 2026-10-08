-- ================================================================
-- SQL DDL (TOPIC 04) - Fitness Center Management, Team 4
-- ================================================================
-- [Boris]     - members (constraints, search indexes)
-- [Oksana]    - trainers
-- [Oleksandr] - membership_plans, memberships, membership_status ENUM
-- [Vasyl]     - attendance
-- [Yehor]     - classes, review fixes
-- ================================================================

CREATE SCHEMA IF NOT EXISTS fitness_center_team4;

--  [Boris] Підключаємо розширення для нечутливості email до регістру
CREATE EXTENSION IF NOT EXISTS citext;

-- ================================================================
-- 1) TYPES
-- ================================================================
-- [Boris] Домен email з перевіркою через Regex та підтримкою CITEXT
CREATE DOMAIN fitness_center_team4.email_address AS CITEXT
    CHECK (VALUE ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$');

CREATE TYPE fitness_center_team4.membership_status AS ENUM (
    'active',
    'expired',
    'frozen',
    'cancelled'
);

-- ================================================================
-- 2) TABLES (in dependency order)
-- ================================================================

-- [Boris]
CREATE TABLE fitness_center_team4.members (
    member_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    email fitness_center_team4.email_address UNIQUE,
    birth_date DATE,
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Перевірка дати народження (від 1900 року до сьогодення)
    CONSTRAINT chk_members_birth_date
        CHECK (birth_date IS NULL OR (birth_date >= DATE '1900-01-01' AND birth_date <= CURRENT_DATE)),
    -- Реєстрація повинна бути пізніше за дату народження
    CONSTRAINT chk_members_registration_after_birth
        CHECK (birth_date IS NULL OR registration_date > birth_date),
    -- Додати обмеження: дата реєстрації має бути пізніше за дату народження
    CONSTRAINT chk_members_reg_date_after_birth
        CHECK (birth_date IS NULL OR registration_date > birth_date),
    -- Захист від порожніх імен з пробілів
    CONSTRAINT chk_members_first_name_not_empty
        CHECK (length(trim(first_name)) > 0),
    CONSTRAINT chk_members_last_name_not_empty
        CHECK (length(trim(last_name)) > 0)
);

-- [Oksana]
CREATE TABLE fitness_center_team4.trainers (
    trainer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE,
    phone VARCHAR(20),
    email fitness_center_team4.email_address UNIQUE,
    hire_date DATE,

    CONSTRAINT chk_trainers_birth_date
        CHECK (birth_date IS NULL OR birth_date >= DATE '1900-01-01'),

    CONSTRAINT chk_trainers_hire_after_birth
        CHECK (birth_date IS NULL OR hire_date IS NULL OR hire_date > birth_date)
);

-- [Oleksandr]
CREATE TABLE fitness_center_team4.membership_plans (
    plan_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL UNIQUE,
    duration_months INTEGER NOT NULL,
    price NUMERIC(10, 2) NOT NULL,

    CONSTRAINT chk_membership_plans_duration_positive
        CHECK (duration_months > 0),
    CONSTRAINT chk_membership_plans_price_non_negative
        CHECK (price >= 0)
);

CREATE TABLE fitness_center_team4.memberships (
    membership_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id INTEGER NOT NULL,
    plan_id INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status fitness_center_team4.membership_status NOT NULL DEFAULT 'active',

    CONSTRAINT fk_memberships_member
        FOREIGN KEY (member_id)
        REFERENCES fitness_center_team4.members(member_id),

    CONSTRAINT fk_memberships_plan
        FOREIGN KEY (plan_id)
        REFERENCES fitness_center_team4.membership_plans(plan_id),

    CONSTRAINT chk_memberships_dates_valid
        CHECK (end_date > start_date)
);

-- [Yehor]
CREATE TABLE fitness_center_team4.classes (
    class_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_name VARCHAR(100) NOT NULL,
    trainer_id INTEGER NOT NULL,
    schedule_datetime TIMESTAMP NOT NULL,

    CONSTRAINT fk_classes_trainer
        FOREIGN KEY (trainer_id)
        REFERENCES fitness_center_team4.trainers(trainer_id),

    CONSTRAINT uq_classes_trainer_schedule
        UNIQUE (trainer_id, schedule_datetime)
);

-- [Vasyl]
CREATE TABLE fitness_center_team4.attendance (
    attendance_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id INTEGER NOT NULL,
    class_id INTEGER NOT NULL,
    checked_in_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_attendance_member
        FOREIGN KEY (member_id)
        REFERENCES fitness_center_team4.members(member_id),

    CONSTRAINT fk_attendance_class
        FOREIGN KEY (class_id)
        REFERENCES fitness_center_team4.classes(class_id),

    CONSTRAINT uq_attendance_member_class
        UNIQUE (member_id, class_id)
);

-- ================================================================
-- 3) INDEXES
-- ================================================================

-- members [Boris]
CREATE INDEX idx_members_last_first_name
    ON fitness_center_team4.members(last_name, first_name);

CREATE INDEX idx_members_phone
    ON fitness_center_team4.members(phone);

-- memberships [Oleksandr]
CREATE INDEX idx_memberships_member_id
    ON fitness_center_team4.memberships(member_id);

CREATE INDEX idx_memberships_plan_id
    ON fitness_center_team4.memberships(plan_id);

-- classes [Yehor]
CREATE INDEX idx_classes_schedule_datetime
    ON fitness_center_team4.classes(schedule_datetime);

-- attendance [Vasyl]
CREATE INDEX idx_attendance_class_id
    ON fitness_center_team4.attendance(class_id);
