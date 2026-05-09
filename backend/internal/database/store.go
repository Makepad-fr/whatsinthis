package database

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

type Store struct {
	db              *sql.DB
	cacheTTL        time.Duration
	similarCacheTTL time.Duration
}

func NewStore(db *sql.DB, cacheTTL, similarCacheTTL time.Duration) *Store {
	return &Store{db: db, cacheTTL: cacheTTL, similarCacheTTL: similarCacheTTL}
}

func (s *Store) CachedProduct(ctx context.Context, key string) (*product.NormalizedProduct, bool, error) {
	var payload []byte
	err := s.db.QueryRowContext(
		ctx,
		`SELECT payload FROM product_cache WHERE key = $1 AND expires_at > now()`,
		key,
	).Scan(&payload)
	if err == sql.ErrNoRows {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("read product cache: %w", err)
	}

	var cached product.NormalizedProduct
	if err := json.Unmarshal(payload, &cached); err != nil {
		return nil, false, fmt.Errorf("decode product cache: %w", err)
	}
	return &cached, true, nil
}

func (s *Store) SaveProduct(ctx context.Context, key string, value product.NormalizedProduct) error {
	payload, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("encode product cache: %w", err)
	}

	now := time.Now().UTC()
	_, err = s.db.ExecContext(
		ctx,
		`INSERT INTO product_cache (key, payload, source, updated_at, expires_at)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (key) DO UPDATE SET
		   payload = EXCLUDED.payload,
		   source = EXCLUDED.source,
		   updated_at = EXCLUDED.updated_at,
		   expires_at = EXCLUDED.expires_at`,
		key,
		payload,
		string(value.Source),
		now,
		now.Add(s.cacheTTL),
	)
	if err != nil {
		return fmt.Errorf("save product cache: %w", err)
	}
	return nil
}

func (s *Store) CachedSimilarProducts(ctx context.Context, key string) ([]product.NormalizedProduct, bool, error) {
	var payload []byte
	err := s.db.QueryRowContext(
		ctx,
		`SELECT payload FROM similar_product_cache WHERE key = $1 AND expires_at > now()`,
		key,
	).Scan(&payload)
	if err == sql.ErrNoRows {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("read similar cache: %w", err)
	}

	var cached []product.NormalizedProduct
	if err := json.Unmarshal(payload, &cached); err != nil {
		return nil, false, fmt.Errorf("decode similar cache: %w", err)
	}
	return cached, true, nil
}

func (s *Store) SaveSimilarProducts(ctx context.Context, key string, values []product.NormalizedProduct) error {
	payload, err := json.Marshal(values)
	if err != nil {
		return fmt.Errorf("encode similar cache: %w", err)
	}

	now := time.Now().UTC()
	_, err = s.db.ExecContext(
		ctx,
		`INSERT INTO similar_product_cache (key, payload, updated_at, expires_at)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (key) DO UPDATE SET
		   payload = EXCLUDED.payload,
		   updated_at = EXCLUDED.updated_at,
		   expires_at = EXCLUDED.expires_at`,
		key,
		payload,
		now,
		now.Add(s.similarCacheTTL),
	)
	if err != nil {
		return fmt.Errorf("save similar cache: %w", err)
	}
	return nil
}

func (s *Store) UpsertGlossaryItems(ctx context.Context, items []product.GlossaryItem) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin glossary seed: %w", err)
	}
	defer tx.Rollback()

	for _, item := range items {
		aliasesValue := item.Aliases
		if aliasesValue == nil {
			aliasesValue = []string{}
		}
		markersValue := item.Markers
		if markersValue == nil {
			markersValue = []string{}
		}

		aliases, err := json.Marshal(aliasesValue)
		if err != nil {
			return fmt.Errorf("encode aliases for %s: %w", item.ID, err)
		}
		markers, err := json.Marshal(markersValue)
		if err != nil {
			return fmt.Errorf("encode markers for %s: %w", item.ID, err)
		}

		if _, err := tx.ExecContext(
			ctx,
			`INSERT INTO ingredient_glossary (id, name, aliases, category, summary, function_text, caution, markers, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
			 ON CONFLICT (id) DO UPDATE SET
			   name = EXCLUDED.name,
			   aliases = EXCLUDED.aliases,
			   category = EXCLUDED.category,
			   summary = EXCLUDED.summary,
			   function_text = EXCLUDED.function_text,
			   caution = EXCLUDED.caution,
			   markers = EXCLUDED.markers,
			   updated_at = now()`,
			item.ID,
			item.Name,
			aliases,
			string(item.Category),
			item.Summary,
			item.Function,
			item.Caution,
			markers,
		); err != nil {
			return fmt.Errorf("upsert glossary item %s: %w", item.ID, err)
		}
	}

	return tx.Commit()
}

func (s *Store) GlossaryItems(ctx context.Context) ([]product.GlossaryItem, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, name, aliases, category, summary, function_text, caution, markers
			 FROM ingredient_glossary
			 ORDER BY lower(name), name`,
	)
	if err != nil {
		return nil, fmt.Errorf("query glossary: %w", err)
	}
	defer rows.Close()

	var items []product.GlossaryItem
	for rows.Next() {
		var item product.GlossaryItem
		var aliases []byte
		var markers []byte
		var category string
		if err := rows.Scan(&item.ID, &item.Name, &aliases, &category, &item.Summary, &item.Function, &item.Caution, &markers); err != nil {
			return nil, fmt.Errorf("scan glossary: %w", err)
		}
		if err := json.Unmarshal(aliases, &item.Aliases); err != nil {
			return nil, fmt.Errorf("decode glossary aliases: %w", err)
		}
		if err := json.Unmarshal(markers, &item.Markers); err != nil {
			return nil, fmt.Errorf("decode glossary markers: %w", err)
		}
		if item.Aliases == nil {
			item.Aliases = []string{}
		}
		if item.Markers == nil {
			item.Markers = []string{}
		}
		item.Category = product.ProductCategory(category)
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate glossary: %w", err)
	}
	return items, nil
}
