package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

func Migrate(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	entries, err := fs.ReadDir(migrationFiles, "migrations")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}

	names := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)

	for _, name := range names {
		applied, err := migrationApplied(ctx, db, name)
		if err != nil {
			return err
		}
		if applied {
			continue
		}

		body, err := migrationFiles.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return fmt.Errorf("begin migration %s: %w", name, err)
		}
		if _, err := tx.ExecContext(ctx, string(body)); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("apply migration %s: %w", name, err)
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO schema_migrations (version) VALUES ($1)`, name); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("record migration %s: %w", name, err)
		}
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("commit migration %s: %w", name, err)
		}
	}

	return nil
}

func migrationApplied(ctx context.Context, db *sql.DB, name string) (bool, error) {
	var exists bool
	if err := db.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE version = $1)`, name).Scan(&exists); err != nil {
		return false, fmt.Errorf("check migration %s: %w", name, err)
	}
	return exists, nil
}
