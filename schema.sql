-- =============================================================================
-- Q-Commerce Platform — Full Production Schema
-- Stack: PostgreSQL 15+ with PostGIS
-- Architecture: Dual-path (Hot WebSocket + Cold Ledger via Transactional Outbox)
-- =============================================================================
-- Table of Contents
--   0. Extensions
--   1. Enumerations
--   2. Platform Config  — branches, fiscal_years
--   3. Identity         — users, addresses
--   4. Catalog          — categories, products
--   5. Inventory        — branch_inventory
--   6. Riders           — riders
--   7. Orders           — orders, order_items
--   8. Outbox           — outbox_events (Transactional Outbox pattern)
--   9. Ledger           — accounts, journals, journal_lines (partitioned)
--  10. Checkpoints      — balance_checkpoints
--  11. Triggers         — double-entry + fiscal boundary enforcement
--  12. Indexes          — all non-primary indexes
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "btree_gist";  -- Required for EXCLUDE USING GIST


-- -----------------------------------------------------------------------------
-- 1. ENUMERATIONS
-- -----------------------------------------------------------------------------

CREATE TYPE entry_type          AS ENUM ('debit', 'credit');
CREATE TYPE account_type        AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');
CREATE TYPE normal_balance_side AS ENUM ('debit', 'credit');
CREATE TYPE outbox_status       AS ENUM ('pending', 'processing', 'processed', 'failed');

CREATE TYPE user_role           AS ENUM ('customer', 'picker', 'rider', 'branch_manager', 'super_admin');
CREATE TYPE order_status        AS ENUM (
    'pending',          -- placed, awaiting branch confirmation
    'confirmed',        -- branch accepted
    'picking',          -- picker is collecting items
    'ready',            -- ready for rider pickup
    'out_for_delivery', -- rider has picked up
    'delivered',        -- completed successfully
    'cancelled',        -- cancelled (pre-pickup)
    'rejected'          -- rejected at doorstep (partial or full)
);
CREATE TYPE order_item_status   AS ENUM ('pending', 'picked', 'substituted', 'rejected');
CREATE TYPE rider_status        AS ENUM ('offline', 'available', 'on_delivery');
CREATE TYPE vehicle_type        AS ENUM ('bicycle', 'motorcycle', 'ev_scooter');


-- =============================================================================
-- 2. PLATFORM CONFIG
-- =============================================================================

CREATE TABLE branches (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code                TEXT            NOT NULL,
    name                TEXT            NOT NULL,
    address_line        TEXT            NOT NULL,
    city                TEXT            NOT NULL,
    -- PostGIS geography point for geofencing and rider proximity queries.
    -- SRID 4326 = WGS84 (standard GPS coordinates).
    location            GEOGRAPHY(POINT, 4326) NOT NULL,
    -- Radius in metres within which this branch serves orders.
    catchment_radius_m  INT             NOT NULL DEFAULT 3000,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    inserted_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT branches_code_unique UNIQUE (code),
    CONSTRAINT branches_catchment_positive CHECK (catchment_radius_m > 0)
);

-- Fiscal years define the accounting period boundary.
-- The EXCLUDE constraint prevents overlapping fiscal years platform-wide.
CREATE TABLE fiscal_years (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    label       TEXT        NOT NULL,
    start_date  DATE        NOT NULL,
    end_date    DATE        NOT NULL,
    is_closed   BOOLEAN     NOT NULL DEFAULT FALSE,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fiscal_years_label_unique UNIQUE (label),
    CONSTRAINT fiscal_years_dates_valid  CHECK (end_date > start_date),
    -- Prevents two fiscal years with overlapping date ranges.
    -- Requires btree_gist extension.
    CONSTRAINT fiscal_years_no_overlap
        EXCLUDE USING GIST (daterange(start_date, end_date, '[]') WITH &&)
);

-- Seed FY2025 (adjust as needed)
INSERT INTO fiscal_years (id, label, start_date, end_date)
VALUES ('aaaaaaaa-0000-0000-0000-000000000001', 'FY2025', '2025-01-01', '2025-12-31');

INSERT INTO fiscal_years (id, label, start_date, end_date)
VALUES ('aaaaaaaa-0000-0000-0000-000000000002', 'FY2026', '2026-01-01', '2026-12-31');


-- =============================================================================
-- 3. IDENTITY
-- =============================================================================

CREATE TABLE users (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           TEXT        NOT NULL,
    phone           TEXT        NOT NULL,
    full_name       TEXT        NOT NULL,
    password_hash   TEXT        NOT NULL,
    role            user_role   NOT NULL DEFAULT 'customer',
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    inserted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_email_unique UNIQUE (email),
    CONSTRAINT users_phone_unique UNIQUE (phone)
);

CREATE TABLE addresses (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label       TEXT        NOT NULL DEFAULT 'Home',   -- 'Home', 'Work', 'Other'
    line1       TEXT        NOT NULL,
    line2       TEXT,
    city        TEXT        NOT NULL,
    -- Stored as PostGIS geography so distance-to-branch queries use
    -- ST_DWithin for index-accelerated proximity checks.
    location    GEOGRAPHY(POINT, 4326),
    is_default  BOOLEAN     NOT NULL DEFAULT FALSE,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- 4. CATALOG
-- =============================================================================

-- Self-referential category tree. parent_id = NULL means root category.
CREATE TABLE categories (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id   UUID        REFERENCES categories(id) ON DELETE SET NULL,
    name        TEXT        NOT NULL,
    slug        TEXT        NOT NULL,
    image_url   TEXT,
    sort_order  INT         NOT NULL DEFAULT 0,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT categories_slug_unique UNIQUE (slug)
);

-- Global product catalog. Prices are branch-scoped (see branch_inventory).
-- base_price here is a reference/default; actual selling price lives in
-- branch_inventory.selling_price to allow per-branch pricing.
CREATE TABLE products (
    id          UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID            NOT NULL REFERENCES categories(id),
    name        TEXT            NOT NULL,
    sku         TEXT            NOT NULL,
    description TEXT,
    base_price  NUMERIC(10, 2)  NOT NULL,
    unit        TEXT            NOT NULL DEFAULT 'piece',  -- 'piece', 'kg', 'litre'
    image_url   TEXT,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    inserted_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT products_sku_unique  UNIQUE (sku),
    CONSTRAINT products_price_positive CHECK (base_price >= 0)
);


-- =============================================================================
-- 5. INVENTORY
-- =============================================================================

-- Branch-local inventory. One row per (branch, product).
-- quantity_on_hand is updated by picker actions and stock receipt events.
-- selling_price allows per-branch price overrides (different city pricing).
CREATE TABLE branch_inventory (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id           UUID            NOT NULL REFERENCES branches(id),
    product_id          UUID            NOT NULL REFERENCES products(id),
    quantity_on_hand    INT             NOT NULL DEFAULT 0,
    reorder_threshold   INT             NOT NULL DEFAULT 10,
    selling_price       NUMERIC(10, 2)  NOT NULL,
    is_available        BOOLEAN         NOT NULL DEFAULT TRUE,
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT branch_inventory_unique      UNIQUE (branch_id, product_id),
    CONSTRAINT branch_inventory_qty_gte_0  CHECK (quantity_on_hand >= 0),
    CONSTRAINT branch_inventory_price_positive CHECK (selling_price >= 0)
);


-- =============================================================================
-- 6. RIDERS
-- =============================================================================

-- One rider profile per user (user.role = 'rider').
-- current_location is updated by the hot path (Phoenix Channel) every N seconds.
-- This column is deliberately NOT write-heavy on the cold path —
-- rider tracking lives in OTP GenServers and is persisted here periodically.
CREATE TABLE riders (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID            NOT NULL REFERENCES users(id),
    vehicle_type        vehicle_type    NOT NULL DEFAULT 'motorcycle',
    license_number      TEXT,
    status              rider_status    NOT NULL DEFAULT 'offline',
    current_location    GEOGRAPHY(POINT, 4326),
    location_updated_at TIMESTAMPTZ,
    inserted_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT riders_user_unique UNIQUE (user_id)
);


-- =============================================================================
-- 7. ORDERS
-- =============================================================================

CREATE TABLE orders (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID            NOT NULL REFERENCES users(id),
    branch_id           UUID            NOT NULL REFERENCES branches(id),
    address_id          UUID            NOT NULL REFERENCES addresses(id),
    rider_id            UUID            REFERENCES riders(id),   -- assigned at dispatch

    status              order_status    NOT NULL DEFAULT 'pending',

    subtotal            NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    delivery_fee        NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    total_amount        NUMERIC(10, 2)  NOT NULL DEFAULT 0,

    -- Populated only for cancellation/rejection events.
    -- These feed the reversal journal via the outbox.
    cancellation_reason TEXT,

    -- Lifecycle timestamps. NULL until the event occurs.
    placed_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    confirmed_at        TIMESTAMPTZ,
    picked_at           TIMESTAMPTZ,
    dispatched_at       TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,

    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT orders_amounts_positive CHECK (
        subtotal >= 0 AND delivery_fee >= 0 AND
        tax_amount >= 0 AND total_amount >= 0
    ),
    CONSTRAINT orders_total_consistent CHECK (
        total_amount = subtotal + delivery_fee + tax_amount
    )
);

CREATE TABLE order_items (
    id          UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id    UUID                NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  UUID                NOT NULL REFERENCES products(id),
    quantity    INT                 NOT NULL,
    unit_price  NUMERIC(10, 2)      NOT NULL,
    line_total  NUMERIC(10, 2)      NOT NULL,
    -- Tracks per-item picker outcome for partial rejection journaling.
    status      order_item_status   NOT NULL DEFAULT 'pending',

    CONSTRAINT order_items_qty_positive    CHECK (quantity > 0),
    CONSTRAINT order_items_price_positive  CHECK (unit_price >= 0),
    CONSTRAINT order_items_total_consistent CHECK (
        line_total = quantity * unit_price
    )
);


-- =============================================================================
-- 8. TRANSACTIONAL OUTBOX
-- Broadway WAL-listener tails this table to populate the ledger.
-- Events are immutable once written. Processed events are marked, never deleted.
-- =============================================================================

CREATE TABLE outbox_events (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- UUIDv5(namespace=order_id, name=event_type). Deterministic and
    -- reconstructible during disaster recovery without a lookup.
    idempotency_key UUID            NOT NULL,

    aggregate_type  TEXT            NOT NULL,   -- 'order', 'inventory_adjustment'
    aggregate_id    UUID            NOT NULL,   -- order_id, batch_id, etc.
    event_type      TEXT            NOT NULL,   -- 'order.delivered', 'order.cancelled'
    payload         JSONB           NOT NULL,
    status          outbox_status   NOT NULL DEFAULT 'pending',
    attempts        SMALLINT        NOT NULL DEFAULT 0,
    last_error      TEXT,

    inserted_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,

    CONSTRAINT outbox_events_idempotency_key_unique UNIQUE (idempotency_key)
);


-- =============================================================================
-- 9. FINANCIAL LEDGER
-- =============================================================================

-- 9a. Chart of Accounts — global, no balance data stored here.
CREATE TABLE accounts (
    id              UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id       UUID                REFERENCES accounts(id),
    code            TEXT                NOT NULL,
    name            TEXT                NOT NULL,
    account_type    account_type        NOT NULL,
    normal_balance  normal_balance_side NOT NULL,
    -- Static shard config. Only powers of 2 between 1 and 16 are valid.
    -- Changing this is a database maintenance event, not a runtime operation.
    shard_count     SMALLINT            NOT NULL DEFAULT 1,
    is_active       BOOLEAN             NOT NULL DEFAULT TRUE,
    inserted_at     TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT accounts_code_unique UNIQUE (code),
    CONSTRAINT accounts_normal_balance_consistent CHECK (
        (account_type IN ('asset', 'expense')               AND normal_balance = 'debit')  OR
        (account_type IN ('liability', 'equity', 'revenue') AND normal_balance = 'credit')
    ),
    CONSTRAINT accounts_shard_count_valid CHECK (shard_count IN (1, 2, 4, 8, 16))
);

-- Seed Chart of Accounts
INSERT INTO accounts (id, code, name, account_type, normal_balance, shard_count) VALUES
    -- Assets
    ('bbbbbbbb-0000-0000-0000-000000000001', '1000', 'Cash',                    'asset',     'debit',  16),
    ('bbbbbbbb-0000-0000-0000-000000000002', '1100', 'Accounts Receivable',     'asset',     'debit',   8),
    ('bbbbbbbb-0000-0000-0000-000000000003', '1200', 'Inventory Asset',         'asset',     'debit',   8),
    -- Liabilities
    ('bbbbbbbb-0000-0000-0000-000000000010', '2000', 'Accounts Payable',        'liability', 'credit',  4),
    ('bbbbbbbb-0000-0000-0000-000000000011', '2100', 'Unearned Revenue',        'liability', 'credit', 16),
    ('bbbbbbbb-0000-0000-0000-000000000012', '2200', 'Tax Payable',             'liability', 'credit',  4),
    -- Revenue
    ('bbbbbbbb-0000-0000-0000-000000000020', '4000', 'Recognized Revenue',      'revenue',   'credit', 16),
    ('bbbbbbbb-0000-0000-0000-000000000021', '4100', 'Delivery Fee Revenue',    'revenue',   'credit',  8),
    -- Expenses
    ('bbbbbbbb-0000-0000-0000-000000000030', '5000', 'Cost of Goods Sold',      'expense',   'debit',   8),
    ('bbbbbbbb-0000-0000-0000-000000000031', '5100', 'Rider Payout Expense',    'expense',   'debit',   8),
    ('bbbbbbbb-0000-0000-0000-000000000032', '5200', 'Office Supplies Expense', 'expense',   'debit',   1);


-- 9b. Journals — one row per business event (the transaction block header).
CREATE TABLE journals (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id       UUID        NOT NULL REFERENCES branches(id),
    fiscal_year_id  UUID        NOT NULL REFERENCES fiscal_years(id),
    -- UUIDv5(order_id, event_type) — same derivation as outbox idempotency key.
    idempotency_key UUID        NOT NULL,
    description     TEXT,
    outbox_event_id UUID        REFERENCES outbox_events(id),
    -- posted_at is the authoritative fiscal timestamp.
    -- Fiscal boundary validated by trigger (see Section 11).
    posted_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    inserted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT journals_idempotency_key_unique UNIQUE (idempotency_key)
);


-- 9c. Journal Lines — partitioned ledger.
--
-- Partition strategy:
--   Level 1: LIST on branch_id    — isolates branch I/O completely
--   Level 2: LIST on fiscal_year_id — enables fiscal-period pruning
--
-- Why LIST and not RANGE on inserted_at?
--   An order placed Dec 31, delivered Jan 1 must land in different fiscal
--   partitions by BUSINESS RULE, not calendar time. LIST on fiscal_year_id
--   gives the application explicit, deterministic control over that assignment.
--
-- Leaf partitions are created by an Oban provisioning job triggered when a
-- new branch or fiscal year is created. Template is in Section 13 below.
CREATE TABLE journal_lines (
    id              UUID            NOT NULL DEFAULT uuid_generate_v4(),
    journal_id      UUID            NOT NULL,
    branch_id       UUID            NOT NULL,   -- Partition key Level 1
    fiscal_year_id  UUID            NOT NULL,   -- Partition key Level 2
    account_id      UUID            NOT NULL REFERENCES accounts(id),
    -- Absolute value, no sign ambiguity. entry_type carries direction.
    amount          NUMERIC(15, 4)  NOT NULL,
    entry_type      entry_type      NOT NULL,
    -- shard_id = ABS(HASHTEXT(order_id::text)) % shard_count
    -- For accounts with shard_count=1, this is always 0.
    shard_id        SMALLINT        NOT NULL DEFAULT 0,
    -- UUIDv5(journal.idempotency_key, line_index::text)
    idempotency_key UUID            NOT NULL,
    posted_at       TIMESTAMPTZ     NOT NULL,
    inserted_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, branch_id, fiscal_year_id),

    CONSTRAINT journal_lines_amount_positive CHECK (amount > 0),
    CONSTRAINT journal_lines_shard_id_valid  CHECK (shard_id >= 0 AND shard_id < 16)

    -- NOTE: FK journal_id → journals(id) is enforced at the LEAF partition
    -- level, not here. PostgreSQL 15 does not support FK constraints referencing
    -- the partition key columns from the parent table across partitions.
    -- Broadway validates journal existence before insert.

) PARTITION BY LIST (branch_id);


-- =============================================================================
-- 10. BALANCE CHECKPOINTS
-- Insert-only materialized cache written exclusively by the Oban checkpoint job.
-- Runtime balance = latest checkpoint totals + delta from journal_lines.
-- Stores CUMULATIVE totals (not deltas) so a balance query needs only ONE
-- checkpoint row + the delta since it — never a chain of checkpoint rows.
-- =============================================================================
CREATE TABLE balance_checkpoints (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id               UUID            NOT NULL REFERENCES branches(id),
    account_id              UUID            NOT NULL REFERENCES accounts(id),
    fiscal_year_id          UUID            NOT NULL REFERENCES fiscal_years(id),
    shard_id                SMALLINT        NOT NULL DEFAULT 0,
    -- Cumulative totals since fiscal year start, through checkpointed_through.
    debit_total             NUMERIC(15, 4)  NOT NULL DEFAULT 0,
    credit_total            NUMERIC(15, 4)  NOT NULL DEFAULT 0,
    -- The precise boundary. Delta query uses: inserted_at > checkpointed_through
    -- Captured as MAX(inserted_at) at the START of the Oban job window.
    checkpointed_through    TIMESTAMPTZ     NOT NULL,
    entry_count             INT             NOT NULL DEFAULT 0,
    inserted_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT balance_checkpoints_shard_valid CHECK (shard_id >= 0 AND shard_id < 16)
);


-- =============================================================================
-- 11. TRIGGERS
-- =============================================================================

-- 11a. Double-Entry Balance Enforcement
-- Fires AFTER COMMIT (DEFERRED) — verifies SUM(debits) = SUM(credits)
-- across ALL lines for a journal. Must be DEFERRED so it fires after
-- all lines are inserted in the same transaction, not after each line.
CREATE OR REPLACE FUNCTION enforce_double_entry_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_debits  NUMERIC(15, 4);
    v_credits NUMERIC(15, 4);
BEGIN
    SELECT
        COALESCE(SUM(amount) FILTER (WHERE entry_type = 'debit'),  0),
        COALESCE(SUM(amount) FILTER (WHERE entry_type = 'credit'), 0)
    INTO v_debits, v_credits
    FROM journal_lines
    WHERE journal_id = NEW.journal_id
      AND branch_id  = NEW.branch_id;

    IF v_debits <> v_credits THEN
        RAISE EXCEPTION
            'Double-entry violation: journal_id=% debits=% credits=%',
            NEW.journal_id, v_debits, v_credits;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER journal_lines_double_entry_check
    AFTER INSERT OR UPDATE ON journal_lines
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION enforce_double_entry_balance();


-- 11b. Fiscal Year Boundary Enforcement
-- Validates posted_at falls within the referenced fiscal_year's date range.
-- Cannot be a CHECK constraint — CHECK cannot reference other tables.
CREATE OR REPLACE FUNCTION enforce_fiscal_year_boundary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_start DATE;
    v_end   DATE;
BEGIN
    SELECT start_date, end_date INTO v_start, v_end
    FROM   fiscal_years WHERE id = NEW.fiscal_year_id;

    IF NEW.posted_at::DATE NOT BETWEEN v_start AND v_end THEN
        RAISE EXCEPTION
            'Fiscal boundary violation: posted_at=% outside fiscal_year_id=% [% to %]',
            NEW.posted_at, NEW.fiscal_year_id, v_start, v_end;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER journal_lines_fiscal_boundary_check
    AFTER INSERT ON journal_lines
    DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
    EXECUTE FUNCTION enforce_fiscal_year_boundary();


-- 11c. updated_at Auto-Maintenance
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER branches_updated_at  BEFORE UPDATE ON branches  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER users_updated_at     BEFORE UPDATE ON users     FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER products_updated_at  BEFORE UPDATE ON products  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER orders_updated_at    BEFORE UPDATE ON orders    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER accounts_updated_at  BEFORE UPDATE ON accounts  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();


-- =============================================================================
-- 12. INDEXES
-- =============================================================================

-- branches
CREATE INDEX branches_location_idx        ON branches USING GIST (location);
CREATE INDEX branches_is_active_idx       ON branches (is_active) WHERE is_active = TRUE;

-- users
CREATE INDEX users_role_idx               ON users (role);

-- addresses
CREATE INDEX addresses_user_id_idx        ON addresses (user_id);
CREATE INDEX addresses_location_idx       ON addresses USING GIST (location);

-- categories
CREATE INDEX categories_parent_id_idx     ON categories (parent_id);
CREATE INDEX categories_slug_idx          ON categories (slug);

-- products
CREATE INDEX products_category_id_idx     ON products (category_id);
CREATE INDEX products_sku_idx             ON products (sku);
CREATE INDEX products_is_active_idx       ON products (is_active) WHERE is_active = TRUE;

-- branch_inventory
CREATE INDEX branch_inventory_branch_idx  ON branch_inventory (branch_id);
CREATE INDEX branch_inventory_product_idx ON branch_inventory (product_id);
CREATE INDEX branch_inventory_available_idx ON branch_inventory (branch_id, is_available)
    WHERE is_available = TRUE;

-- riders
CREATE INDEX riders_user_id_idx           ON riders (user_id);
CREATE INDEX riders_status_idx            ON riders (status);
CREATE INDEX riders_location_idx          ON riders USING GIST (current_location);

-- orders — hot read paths for branch dashboards and rider apps
CREATE INDEX orders_user_id_idx           ON orders (user_id);
CREATE INDEX orders_branch_id_idx         ON orders (branch_id);
CREATE INDEX orders_rider_id_idx          ON orders (rider_id) WHERE rider_id IS NOT NULL;
CREATE INDEX orders_status_idx            ON orders (status);
CREATE INDEX orders_branch_status_idx     ON orders (branch_id, status);
CREATE INDEX orders_placed_at_idx         ON orders (placed_at DESC);

-- order_items
CREATE INDEX order_items_order_id_idx     ON order_items (order_id);
CREATE INDEX order_items_product_id_idx   ON order_items (product_id);

-- outbox_events — Broadway tails this index exclusively
CREATE INDEX outbox_events_pending_idx    ON outbox_events (inserted_at ASC)
    WHERE status = 'pending';
CREATE INDEX outbox_events_aggregate_idx  ON outbox_events (aggregate_type, aggregate_id);

-- journals
CREATE INDEX journals_branch_id_idx       ON journals (branch_id);
CREATE INDEX journals_fiscal_year_id_idx  ON journals (fiscal_year_id);
CREATE INDEX journals_posted_at_idx       ON journals (posted_at DESC);

-- journal_lines — THE CRITICAL COMPOSITE INDEX
-- Drives the hot delta-balance query: WHERE branch + account + fiscal_year + inserted_at > boundary
-- INCLUDE pushes amount and entry_type into index leaf pages = true index-only scan (no heap fetch)
-- Propagates automatically to all child partitions (PostgreSQL 11+)
CREATE INDEX journal_lines_balance_scan_idx
    ON journal_lines (branch_id, account_id, shard_id, inserted_at DESC)
    INCLUDE (amount, entry_type);

CREATE INDEX journal_lines_journal_id_idx
    ON journal_lines (journal_id, branch_id, fiscal_year_id);

CREATE UNIQUE INDEX journal_lines_idempotency_key_idx
    ON journal_lines (idempotency_key, branch_id, fiscal_year_id);

-- balance_checkpoints — latest checkpoint lookup per shard
CREATE INDEX balance_checkpoints_latest_idx
    ON balance_checkpoints (branch_id, account_id, fiscal_year_id, shard_id, inserted_at DESC);

-- accounts
CREATE INDEX accounts_parent_id_idx       ON accounts (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX accounts_code_idx            ON accounts (code);


-- =============================================================================
-- 13. PARTITION PROVISIONING TEMPLATE
-- Execute dynamically via an Oban provisioning job triggered on branch or
-- fiscal_year creation. Partitions MUST exist before the first insert.
-- =============================================================================

/*
-- Step 1: Create Level 1 branch partition (once per branch)
CREATE TABLE journal_lines_branch_<branch_slug>
    PARTITION OF journal_lines
    FOR VALUES IN ('<branch_uuid>');

-- Step 2: Create Level 2 fiscal-year sub-partition (once per branch × fiscal year)
CREATE TABLE journal_lines_branch_<branch_slug>_fy_<year>
    PARTITION OF journal_lines_branch_<branch_slug>
    FOR VALUES IN ('<fiscal_year_uuid>');

-- The composite index defined on the parent table propagates automatically.
-- No manual index creation is needed on leaf partitions.

-- Example: Branch code BLR-01, FY2025
CREATE TABLE journal_lines_branch_blr_01
    PARTITION OF journal_lines
    FOR VALUES IN ('00000000-0000-0000-0000-000000000099');

CREATE TABLE journal_lines_branch_blr_01_fy2025
    PARTITION OF journal_lines_branch_blr_01
    FOR VALUES IN ('aaaaaaaa-0000-0000-0000-000000000001');
*/
