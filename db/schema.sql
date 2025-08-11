CREATE TABLE event_store
(
    id          BIGSERIAL PRIMARY KEY,
    stream_id   TEXT        NOT NULL, -- e.g., "account:{uuid}", "import:{uuid}"
    stream_type TEXT        NOT NULL, -- "account" | "import" | "txn"
    version     INT         NOT NULL, -- per-stream sequence (optimistic locking)
    event_type  TEXT        NOT NULL, -- e.g., "ImportStarted"
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload     JSONB       NOT NULL
);
CREATE UNIQUE INDEX ux_event_stream_version ON event_store (stream_id, version);
CREATE INDEX ix_event_type ON event_store (event_type);

-- Accounts (projection)
CREATE TABLE account
(
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    bank_name           TEXT,
    account_number_hash TEXT UNIQUE,
    type                TEXT CHECK (type IN ('checking', 'savings', 'credit', 'investment', 'other')),
    currency            TEXT NOT NULL DEFAULT 'USD',
    created_at          TIMESTAMPTZ   DEFAULT now()
);

-- Imports (projection)
CREATE TABLE import_job
(
    id              UUID PRIMARY KEY,
    account_id      UUID REFERENCES account (id) ON DELETE CASCADE,
    source_filename TEXT        NOT NULL,
    format          TEXT CHECK (format IN ('csv', 'ofx')),
    started_at      TIMESTAMPTZ NOT NULL                              DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    row_count       INT                                               DEFAULT 0,
    status          TEXT CHECK (status IN ('pending', 'ok', 'error')) DEFAULT 'pending',
    error_message   TEXT
);

-- Raw rows extracted from import job
CREATE TABLE raw_transaction
(
    id            UUID PRIMARY KEY,
    import_job_id UUID REFERENCES import_job (id) ON DELETE CASCADE,
    description   TEXT           NOT NULL,
    amount        NUMERIC(14, 2) NOT NULL
);

-- Categories
CREATE TABLE category
(
    id         UUID PRIMARY KEY,
    name       TEXT UNIQUE NOT NULL, -- "Groceries", "Rent", "Restaurants"
    parent_id  UUID REFERENCES category (id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Transfer groups (projection)
-- CREATE TABLE transfer_group
-- (
--     id         UUID PRIMARY KEY,
--     matched_at TIMESTAMPTZ    NOT NULL DEFAULT now(),
--     amount     NUMERIC(14, 2) NOT NULL,
--     note       TEXT
-- );

-- normalized transactions
CREATE TABLE transaction
(
    id                UUID PRIMARY KEY,
    account_id        UUID REFERENCES account (id) ON DELETE CASCADE,
    import_job_id     UUID REFERENCES import_job (id) ON DELETE CASCADE,
    txn_date          DATE           NOT NULL,
    description       TEXT           NOT NULL, -- original description from bank
    normalized_desc   TEXT,                    -- cleaned version for AI/rules
    amount            NUMERIC(14, 2) NOT NULL, -- negative = debit, positive = credit
    currency          TEXT        DEFAULT 'USD',
    category_id       UUID REFERENCES category (id),
    is_transfer       BOOLEAN     DEFAULT false,
    transfer_group_id BIGINT,                  -- link to internal_transfers
    metadata          JSONB,                   -- raw bank fields
    created_at        TIMESTAMPTZ DEFAULT now(),
    fingerprint       TEXT           NOT NULL, -- hash of (account_id, posted_at, normDesc, amount, fitid?)
    UNIQUE (fingerprint)
);
CREATE INDEX ix_txn_account_date ON transaction (account_id, txn_date);
CREATE INDEX ix_txn_category ON transaction (category_id);
CREATE INDEX ix_txn_transfer ON transaction (is_transfer, amount);

-- Internal transfers grouping
-- CREATE TABLE internal_transfers
-- (
--     id                UUID PRIMARY KEY,
--     group_key         TEXT UNIQUE    NOT NULL, -- hash(amount+date+accounts)
--     amount            NUMERIC(14, 2) NOT NULL,
--     source_account_id UUID REFERENCES account (id),
--     target_account_id UUID REFERENCES account (id),
--     detected_at       TIMESTAMPTZ DEFAULT now()
-- );

-- Rules for auto-categorization (optional, for rule-based MVP)
-- CREATE TABLE category_rules
-- (
--     id          UUID PRIMARY KEY,
--     keyword     TEXT NOT NULL, -- e.g., "UBER", "WALMART"
--     category_id UUID REFERENCES category (id),
--     created_at  TIMESTAMPTZ DEFAULT now()
-- );
