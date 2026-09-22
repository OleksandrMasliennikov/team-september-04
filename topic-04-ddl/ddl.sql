-- ================================================================
-- SQL DDL TEMPLATE (TOPIC 04)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) Full PostgreSQL DDL for your finalized schema.
-- 2) CREATE TABLE statements for all entities from your ER diagram.
-- 3) Primary keys, foreign keys, NOT NULL, UNIQUE, CHECK constraints.
-- 4) Indexes for important search/join columns.
-- 5) Clean structure and comments (group by tables/constraints/indexes).
--
-- RECOMMENDED ORDER:
-- 1) Tables
-- 2) Constraints (if not inline)
-- 3) Indexes
--
-- TEAM NOTE:
-- Add short attribution comments for who implemented which part.
-- Example:
-- [Name] - users, roles, permissions tables
-- [Name] - orders, payments, invoices tables
-- [Oleksandr] - membership_plans and memberships tables, membership_status ENUM, constraints, foreign keys, and indexes
--
-- IMPORTANT:
-- The script must run in PostgreSQL and produce a working schema that
-- matches your approved ER diagram and conceptual schema.
-- Submit this as one SQL file.
-- ================================================================

-- Add your DDL below this line
CREATE SCHEMA IF NOT EXISTS fitness_center_team4;

CREATE TYPE fitness_center_team4.membership_status AS ENUM (
    'active',
    'expired',
    'frozen',
    'cancelled'
);

CREATE TABLE fitness_center_team4.membership_plans (
    plan_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL UNIQUE,
    duration_months INTEGER NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    CONSTRAINT chk_duration_positive CHECK (duration_months > 0),
    CONSTRAINT chk_price_non_negative CHECK (price >= 0)
);

CREATE TABLE fitness_center_team4.memberships (
    membership_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id INTEGER NOT NULL,
    plan_id INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status fitness_center_team4.membership_status NOT NULL DEFAULT 'active',

    CONSTRAINT fk_memberships_member FOREIGN KEY (member_id) REFERENCES fitness_center_team4.members(member_id),

    CONSTRAINT fk_memberships_plan FOREIGN KEY (plan_id) REFERENCES fitness_center_team4.membership_plans(plan_id),

    CONSTRAINT chk_dates_valid CHECK (end_date > start_date)
);

CREATE INDEX idx_memberships_member_id
    ON fitness_center_team4.memberships(member_id);

CREATE INDEX idx_memberships_plan_id
    ON fitness_center_team4.memberships(plan_id);
