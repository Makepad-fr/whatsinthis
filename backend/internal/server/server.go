package server

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

type ProductService interface {
	LookupProduct(ctx context.Context, request product.LookupRequest) (product.LookupResponse, error)
	SimilarProducts(ctx context.Context, request product.SimilarProductsRequest) ([]product.NormalizedProduct, error)
	GlossaryItems(ctx context.Context) ([]product.GlossaryItem, error)
}

type API struct {
	service ProductService
	db      *sql.DB
}

func New(service ProductService, db *sql.DB) http.Handler {
	api := &API{service: service, db: db}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", api.healthz)
	mux.HandleFunc("GET /readyz", api.readyz)
	mux.HandleFunc("POST /v1/products/lookup", api.lookupProduct)
	mux.HandleFunc("POST /v1/products/similar", api.similarProducts)
	mux.HandleFunc("GET /v1/glossary", api.glossaryItems)
	return mux
}

func (api *API) healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (api *API) readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := api.db.PingContext(ctx); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database is not ready")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (api *API) lookupProduct(w http.ResponseWriter, r *http.Request) {
	var request product.LookupRequest
	if !decodeJSON(w, r, &request) {
		return
	}

	response, err := api.service.LookupProduct(r.Context(), request)
	if err != nil {
		writeError(w, http.StatusBadGateway, "product lookup failed")
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (api *API) similarProducts(w http.ResponseWriter, r *http.Request) {
	var request product.SimilarProductsRequest
	if !decodeJSON(w, r, &request) {
		return
	}

	response, err := api.service.SimilarProducts(r.Context(), request)
	if err != nil {
		var status product.HTTPStatusError
		if errors.As(err, &status) {
			writeError(w, status.Code, http.StatusText(status.Code))
			return
		}
		writeError(w, http.StatusBadGateway, "similar products lookup failed")
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (api *API) glossaryItems(w http.ResponseWriter, r *http.Request) {
	items, err := api.service.GlossaryItems(r.Context())
	if err != nil {
		writeError(w, http.StatusBadGateway, "glossary lookup failed")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON request")
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, message string) {
	if message == "" {
		message = http.StatusText(status)
	}
	writeJSON(w, status, map[string]string{"error": message})
}
