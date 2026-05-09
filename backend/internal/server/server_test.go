package server

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

func TestLookupProductEndpoint(t *testing.T) {
	service := fakeService{
		lookupResponse: product.LookupResponse{
			Product: &product.NormalizedProduct{
				ID:                    "123",
				Barcode:               product.StringPtr("123"),
				Name:                  "Test Product",
				IngredientTags:        []string{},
				CategoryTags:          []string{},
				Additives:             []string{},
				Allergens:             []string{},
				Category:              product.ProductCategoryFood,
				Source:                product.ScanSourceOpenFoodFacts,
				IngredientsProvenance: product.IngredientProvenanceAPI,
			},
		},
	}
	request := httptest.NewRequest(http.MethodPost, "/v1/products/lookup", strings.NewReader(`{"barcode":"123","localeIdentifier":"fr_FR"}`))
	response := httptest.NewRecorder()

	New(service, &sql.DB{}).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	var payload product.LookupResponse
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		t.Fatal(err)
	}
	if payload.Product == nil || payload.Product.Name != "Test Product" {
		t.Fatalf("unexpected payload: %#v", payload)
	}
}

func TestGlossaryEndpoint(t *testing.T) {
	service := fakeService{
		glossaryItems: []product.GlossaryItem{
			{ID: "salt", Name: "Salt", Category: product.ProductCategoryFood},
		},
	}
	request := httptest.NewRequest(http.MethodGet, "/v1/glossary", nil)
	response := httptest.NewRecorder()

	New(service, &sql.DB{}).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	var payload []product.GlossaryItem
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		t.Fatal(err)
	}
	if len(payload) != 1 || payload[0].ID != "salt" {
		t.Fatalf("unexpected payload: %#v", payload)
	}
}

type fakeService struct {
	lookupResponse  product.LookupResponse
	similarResponse []product.NormalizedProduct
	glossaryItems   []product.GlossaryItem
}

func (f fakeService) LookupProduct(context.Context, product.LookupRequest) (product.LookupResponse, error) {
	return f.lookupResponse, nil
}

func (f fakeService) SimilarProducts(context.Context, product.SimilarProductsRequest) ([]product.NormalizedProduct, error) {
	return f.similarResponse, nil
}

func (f fakeService) GlossaryItems(context.Context) ([]product.GlossaryItem, error) {
	return f.glossaryItems, nil
}
