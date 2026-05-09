package database

import (
	"context"
	"database/sql"
	"os"
	"testing"
	"time"

	_ "github.com/lib/pq"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

func TestStoreIntegration(t *testing.T) {
	dsn := os.Getenv("POSTGRES_TEST_DSN")
	if dsn == "" {
		t.Skip("POSTGRES_TEST_DSN is not set")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if err := Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}

	store := NewStore(db, time.Hour, time.Hour)
	item := product.GlossaryItem{ID: "test-salt", Name: "Test Salt", Category: product.ProductCategoryFood}
	if err := store.UpsertGlossaryItems(ctx, []product.GlossaryItem{item}); err != nil {
		t.Fatal(err)
	}
	items, err := store.GlossaryItems(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) == 0 {
		t.Fatal("expected seeded glossary items")
	}

	normalized := product.NormalizedProduct{
		ID:                    "123",
		Barcode:               product.StringPtr("123"),
		Name:                  "Cached Product",
		IngredientTags:        []string{},
		CategoryTags:          []string{},
		Additives:             []string{},
		Allergens:             []string{},
		Category:              product.ProductCategoryFood,
		Source:                product.ScanSourceOpenFoodFacts,
		IngredientsProvenance: product.IngredientProvenanceAPI,
		CapturedAt:            time.Now().UTC(),
	}
	if err := store.SaveProduct(ctx, "123", normalized); err != nil {
		t.Fatal(err)
	}
	cached, ok, err := store.CachedProduct(ctx, "123")
	if err != nil {
		t.Fatal(err)
	}
	if !ok || cached.Name != "Cached Product" {
		t.Fatalf("cached = %#v, ok = %v", cached, ok)
	}
}
