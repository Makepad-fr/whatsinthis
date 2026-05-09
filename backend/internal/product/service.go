package product

import (
	"context"
	"errors"
	"fmt"
	"strings"
)

type Store interface {
	CachedProduct(ctx context.Context, key string) (*NormalizedProduct, bool, error)
	SaveProduct(ctx context.Context, key string, product NormalizedProduct) error
	CachedSimilarProducts(ctx context.Context, key string) ([]NormalizedProduct, bool, error)
	SaveSimilarProducts(ctx context.Context, key string, products []NormalizedProduct) error
	GlossaryItems(ctx context.Context) ([]GlossaryItem, error)
}

type Source interface {
	LookupProduct(ctx context.Context, scannedBarcode string, lookupBarcode string) (LookupResponse, error)
	SimilarProducts(ctx context.Context, product NormalizedProduct, limit int) ([]NormalizedProduct, error)
}

type HTTPStatusError struct {
	Code int
}

func (e HTTPStatusError) Error() string {
	return fmt.Sprintf("HTTP %d", e.Code)
}

type Service struct {
	store  Store
	source Source
}

func NewService(store Store, source Source) *Service {
	return &Service{store: store, source: source}
}

func (s *Service) LookupProduct(ctx context.Context, request LookupRequest) (LookupResponse, error) {
	scannedBarcode := NormalizeBarcode(request.Barcode)
	if scannedBarcode == "" {
		message := "No product barcode was provided."
		return LookupResponse{Message: &message}, nil
	}

	for _, candidate := range LookupCandidates(scannedBarcode) {
		if cached, ok, err := s.store.CachedProduct(ctx, candidate); err != nil {
			return LookupResponse{}, err
		} else if ok {
			cachedCopy := *cached
			cachedCopy.Source = ScanSourceCache
			return LookupResponse{Product: &cachedCopy}, nil
		}
	}

	sawSourceFailure := false
	for _, candidate := range LookupCandidates(scannedBarcode) {
		response, err := s.source.LookupProduct(ctx, scannedBarcode, candidate)
		if err != nil {
			sawSourceFailure = true
			continue
		}
		if response.Product == nil {
			continue
		}
		if err := s.store.SaveProduct(ctx, scannedBarcode, *response.Product); err != nil {
			return LookupResponse{}, err
		}
		return response, nil
	}

	if sawSourceFailure {
		message := "The product code was recognized, but the product sources could not return a verified record right now. Check your connection or capture the ingredient label to continue."
		return LookupResponse{Message: &message}, nil
	}

	message := fmt.Sprintf("Recognized product code %s, but no matching product record was found in Open Food Facts, Open Beauty Facts, or USDA. Capture the ingredient label to continue.", scannedBarcode)
	return LookupResponse{Message: &message}, nil
}

func (s *Service) SimilarProducts(ctx context.Context, request SimilarProductsRequest) ([]NormalizedProduct, error) {
	if request.Limit <= 0 || request.Product.Category != ProductCategoryFood {
		return []NormalizedProduct{}, nil
	}

	key := similarCacheKey(request.Product, request.Limit)
	if cached, ok, err := s.store.CachedSimilarProducts(ctx, key); err != nil {
		return nil, err
	} else if ok {
		return cached, nil
	}

	products, err := s.source.SimilarProducts(ctx, request.Product, request.Limit)
	if err != nil {
		var status HTTPStatusError
		if errors.As(err, &status) && (status.Code == 429 || status.Code == 503) {
			return nil, status
		}
		return nil, err
	}
	if err := s.store.SaveSimilarProducts(ctx, key, products); err != nil {
		return nil, err
	}
	return products, nil
}

func (s *Service) GlossaryItems(ctx context.Context) ([]GlossaryItem, error) {
	items, err := s.store.GlossaryItems(ctx)
	if err != nil {
		return nil, err
	}
	return SortedGlossary(items), nil
}

func similarCacheKey(product NormalizedProduct, limit int) string {
	barcode := ""
	if product.Barcode != nil {
		barcode = NormalizeBarcode(*product.Barcode)
	}
	if barcode == "" {
		barcode = NormalizedName(product.ID + ":" + product.Name)
	}
	return fmt.Sprintf("%s:%d:%s", barcode, limit, strings.Join(product.CategoryTags, ","))
}
