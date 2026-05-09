CREATE TABLE IF NOT EXISTS schema_migrations (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS product_cache (
    key text PRIMARY KEY,
    payload jsonb NOT NULL,
    source text NOT NULL,
    updated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS similar_product_cache (
    key text PRIMARY KEY,
    payload jsonb NOT NULL,
    updated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS ingredient_glossary (
    id text PRIMARY KEY,
    name text NOT NULL,
    aliases jsonb NOT NULL,
    category text NOT NULL,
    summary text NOT NULL,
    function_text text NOT NULL,
    caution boolean NOT NULL,
    markers jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS product_cache_expires_at_idx ON product_cache (expires_at);
CREATE INDEX IF NOT EXISTS similar_product_cache_expires_at_idx ON similar_product_cache (expires_at);
CREATE INDEX IF NOT EXISTS ingredient_glossary_name_idx ON ingredient_glossary (name);
