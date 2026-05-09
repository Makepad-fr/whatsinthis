package glossary

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

//go:embed data/ingredient_glossary.json
var files embed.FS

type Store interface {
	UpsertGlossaryItems(ctx context.Context, items []product.GlossaryItem) error
}

func Seed(ctx context.Context, store Store) error {
	body, err := files.ReadFile("data/ingredient_glossary.json")
	if err != nil {
		return fmt.Errorf("read embedded glossary: %w", err)
	}

	var items []product.GlossaryItem
	if err := json.Unmarshal(body, &items); err != nil {
		return fmt.Errorf("decode embedded glossary: %w", err)
	}
	return store.UpsertGlossaryItems(ctx, items)
}
