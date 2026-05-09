package source

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

type Config struct {
	HTTPClient *http.Client
	UserAgent  string
	USDAKey    string
}

type Client struct {
	httpClient *http.Client
	userAgent  string
	usdaKey    string
}

type sourceAttempt struct {
	product   *product.NormalizedProduct
	succeeded bool
}

func NewClient(cfg Config) *Client {
	httpClient := cfg.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 6 * time.Second}
	}
	userAgent := strings.TrimSpace(cfg.UserAgent)
	if userAgent == "" {
		userAgent = "WhatsInThis/1.0 (backend)"
	}
	return &Client{httpClient: httpClient, userAgent: userAgent, usdaKey: strings.TrimSpace(cfg.USDAKey)}
}

func (c *Client) LookupProduct(ctx context.Context, scannedBarcode string, lookupBarcode string) (product.LookupResponse, error) {
	attempts := []sourceAttempt{
		c.attempt(ctx, func(context.Context) (*product.NormalizedProduct, error) {
			return c.lookupFoodOFF(ctx, lookupBarcode)
		}),
		c.attempt(ctx, func(context.Context) (*product.NormalizedProduct, error) {
			return c.lookupBeautyOBF(ctx, lookupBarcode)
		}),
		c.attempt(ctx, func(context.Context) (*product.NormalizedProduct, error) {
			return c.lookupUSDA(ctx, lookupBarcode)
		}),
	}

	var candidates []product.NormalizedProduct
	for _, attempt := range attempts {
		if attempt.product != nil {
			candidates = append(candidates, rebaseProduct(*attempt.product, scannedBarcode))
		}
	}

	if preferred := preferredCandidate(candidates); preferred != nil {
		if strings.TrimSpace(preferred.IngredientText) == "" {
			message := fmt.Sprintf("Found %s in %s, but that record does not include an ingredient list. Capture the ingredient label to continue.", preferred.Name, displaySource(preferred.Source))
			return product.LookupResponse{Product: preferred, Message: &message}, nil
		}
		return product.LookupResponse{Product: preferred}, nil
	}

	allFailed := len(attempts) > 0
	for _, attempt := range attempts {
		if attempt.succeeded {
			allFailed = false
			break
		}
	}
	if allFailed {
		return product.LookupResponse{}, errors.New("all product sources failed")
	}
	return product.LookupResponse{}, nil
}

func (c *Client) SimilarProducts(ctx context.Context, value product.NormalizedProduct, limit int) ([]product.NormalizedProduct, error) {
	if value.Category != product.ProductCategoryFood || limit <= 0 {
		return []product.NormalizedProduct{}, nil
	}

	fields := strings.Join([]string{
		"code", "product_name", "brands", "image_front_small_url", "ingredients_text",
		"ingredients_tags", "allergens_tags", "additives_tags", "categories_tags",
		"nutriments", "nutrition_grade_fr", "nutriscore_grade", "nova_group",
	}, ",")

	currentBarcode := ""
	if value.Barcode != nil {
		currentBarcode = product.NormalizeBarcode(*value.Barcode)
	}
	currentName := product.NormalizedName(value.Name)
	pageSize := strconv.Itoa(min(max(limit, 4), 6))

	var candidates []product.NormalizedProduct
	var saw429 bool
	var saw503 bool
	var sawOtherFailure bool

	for _, target := range recommendationSearchTargets(value) {
		matches, err := c.fetchSimilarFoodProductsSearch(ctx, target, pageSize, fields)
		if err != nil {
			var status product.HTTPStatusError
			if errors.As(err, &status) {
				saw429 = saw429 || status.Code == http.StatusTooManyRequests
				saw503 = saw503 || status.Code == http.StatusServiceUnavailable
				sawOtherFailure = sawOtherFailure || (status.Code != http.StatusTooManyRequests && status.Code != http.StatusServiceUnavailable)
				if status.Code == http.StatusTooManyRequests {
					break
				}
			} else {
				sawOtherFailure = true
			}
			continue
		}

		candidates = append(candidates, matches...)
		if len(matches) > 0 {
			break
		}
		if len(candidates) >= max(limit*2, 8) {
			break
		}
	}

	deduped := product.DeduplicateProducts(candidates)
	result := make([]product.NormalizedProduct, 0, limit)
	for _, candidate := range deduped {
		candidateBarcode := ""
		if candidate.Barcode != nil {
			candidateBarcode = product.NormalizeBarcode(*candidate.Barcode)
		}
		sameBarcode := currentBarcode != "" && candidateBarcode == currentBarcode
		sameName := product.NormalizedName(candidate.Name) == currentName
		hasNutrition := candidate.Nutrition != nil && candidate.Nutrition.HasAnyValue()
		if sameBarcode || sameName || !hasNutrition {
			continue
		}
		result = append(result, candidate)
		if len(result) >= limit {
			break
		}
	}

	if len(result) == 0 {
		switch {
		case saw429:
			return nil, product.HTTPStatusError{Code: http.StatusTooManyRequests}
		case saw503:
			return nil, product.HTTPStatusError{Code: http.StatusServiceUnavailable}
		case sawOtherFailure:
			return nil, product.HTTPStatusError{Code: http.StatusBadGateway}
		}
	}

	return result, nil
}

func (c *Client) attempt(ctx context.Context, operation func(context.Context) (*product.NormalizedProduct, error)) sourceAttempt {
	value, err := operation(ctx)
	if err != nil {
		return sourceAttempt{succeeded: false}
	}
	return sourceAttempt{product: value, succeeded: true}
}

func (c *Client) lookupFoodOFF(ctx context.Context, barcode string) (*product.NormalizedProduct, error) {
	fields := strings.Join([]string{
		"code", "product_name", "brands", "image_front_small_url", "ingredients_text",
		"ingredients_text_en", "ingredients_tags", "allergens_tags", "additives_tags",
		"abbreviated_product_name", "generic_name", "categories_tags", "product_quantity",
		"quantity", "nutriments", "nutrition_grade_fr", "nutriscore_grade", "nova_group",
		"ecoscore_grade",
	}, ",")
	endpoint := fmt.Sprintf("https://world.openfoodfacts.org/api/v2/product/%s.json?fields=%s", url.PathEscape(barcode), url.QueryEscape(fields))

	var response offProductResponse
	if err := c.fetchJSON(ctx, endpoint, &response); err != nil {
		return nil, err
	}
	if response.Status != 1 || response.Product == nil {
		return nil, nil
	}
	return normalizedFoodProduct(*response.Product, barcode), nil
}

func (c *Client) lookupBeautyOBF(ctx context.Context, barcode string) (*product.NormalizedProduct, error) {
	fields := strings.Join([]string{
		"code", "product_name", "brands", "image_front_small_url", "ingredients_text",
		"ingredients_tags", "categories_tags", "abbreviated_product_name", "generic_name",
	}, ",")
	endpoint := fmt.Sprintf("https://world.openbeautyfacts.org/api/v2/product/%s.json?fields=%s", url.PathEscape(barcode), url.QueryEscape(fields))

	var response obfProductResponse
	if err := c.fetchJSON(ctx, endpoint, &response); err != nil {
		return nil, err
	}
	if response.Status != 1 || response.Product == nil {
		return nil, nil
	}

	p := response.Product
	ingredientText := nonEmpty(p.IngredientsText)
	categoryTags := stringSlice(p.CategoriesTags)
	name := resolvedName(p.ProductName, p.AbbreviatedProductName, p.GenericName, ingredientText, categoryTags)

	return &product.NormalizedProduct{
		ID:                    "beauty-" + barcode,
		Barcode:               product.StringPtr(barcode),
		Name:                  name,
		Brand:                 product.StringPtr(nonEmpty(p.Brands)),
		ImageURL:              product.StringPtr(nonEmpty(p.ImageFrontSmallURL)),
		IngredientText:        ingredientText,
		IngredientTags:        stringSlice(p.IngredientsTags),
		CategoryTags:          categoryTags,
		Additives:             []string{},
		Allergens:             []string{},
		Category:              product.ProductCategoryBeauty,
		Source:                product.ScanSourceOpenBeautyFacts,
		IngredientsProvenance: product.IngredientProvenanceAPI,
		CapturedAt:            time.Now().UTC(),
	}, nil
}

func (c *Client) lookupUSDA(ctx context.Context, barcode string) (*product.NormalizedProduct, error) {
	if c.usdaKey == "" {
		return nil, nil
	}

	params := url.Values{}
	params.Set("query", barcode)
	params.Set("dataType", "Branded")
	params.Set("pageSize", "5")
	params.Set("api_key", c.usdaKey)
	endpoint := "https://api.nal.usda.gov/fdc/v1/foods/search?" + params.Encode()

	var response usdaSearchResponse
	if err := c.fetchJSON(ctx, endpoint, &response); err != nil {
		return nil, err
	}

	for _, food := range response.Foods {
		if product.NormalizeBarcode(food.GTINUPC) != barcode {
			continue
		}
		category := "branded"
		if strings.TrimSpace(food.FoodCategory) != "" {
			category = food.FoodCategory
		}
		return &product.NormalizedProduct{
			ID:                    fmt.Sprintf("usda-%d", food.FDCID),
			Barcode:               product.StringPtr(barcode),
			Name:                  food.Description,
			Brand:                 product.StringPtr(strings.TrimSpace(food.BrandOwner)),
			IngredientText:        strings.TrimSpace(food.Ingredients),
			IngredientTags:        []string{},
			CategoryTags:          []string{category},
			Additives:             []string{},
			Allergens:             []string{},
			Category:              product.ProductCategoryFood,
			Source:                product.ScanSourceUSDA,
			IngredientsProvenance: product.IngredientProvenanceAPI,
			CapturedAt:            time.Now().UTC(),
		}, nil
	}
	return nil, nil
}

func (c *Client) fetchSimilarFoodProductsSearch(ctx context.Context, target recommendationSearchTarget, pageSize string, fields string) ([]product.NormalizedProduct, error) {
	hosts := []string{
		"https://world.openfoodfacts.net/api/v2/search",
		"https://world.openfoodfacts.org/api/v2/search",
	}

	var lastErr error
	for _, host := range hosts {
		params := url.Values{}
		params.Set("categories_tags_en", target.searchValue)
		params.Set("page_size", pageSize)
		params.Set("sort_by", "unique_scans_n")
		params.Set("fields", fields)

		var response offSearchResponse
		if err := c.fetchJSON(ctx, host+"?"+params.Encode(), &response); err != nil {
			lastErr = err
			continue
		}

		result := make([]product.NormalizedProduct, 0, len(response.Products))
		for _, p := range response.Products {
			normalized := normalizedFoodProduct(p, nonEmpty(p.Code))
			if normalized != nil {
				result = append(result, *normalized)
			}
		}
		return result, nil
	}

	if lastErr != nil {
		return nil, lastErr
	}
	return nil, product.HTTPStatusError{Code: http.StatusBadGateway}
}

func (c *Client) fetchJSON(ctx context.Context, endpoint string, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", c.userAgent)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		_, _ = io.Copy(io.Discard, resp.Body)
		return product.HTTPStatusError{Code: resp.StatusCode}
	}

	decoder := json.NewDecoder(resp.Body)
	return decoder.Decode(target)
}

func normalizedFoodProduct(p offProduct, fallbackBarcode string) *product.NormalizedProduct {
	resolvedBarcode := nonEmpty(p.Code)
	if resolvedBarcode == "" {
		resolvedBarcode = fallbackBarcode
	}
	if strings.TrimSpace(resolvedBarcode) == "" {
		return nil
	}

	ingredientText := nonEmpty(p.IngredientsTextEN)
	if ingredientText == "" {
		ingredientText = nonEmpty(p.IngredientsText)
	}
	categoryTags := stringSlice(p.CategoriesTags)
	name := resolvedName(p.ProductName, p.AbbreviatedProductName, p.GenericName, ingredientText, categoryTags)
	nutrition := nutritionSnapshot(p)

	return &product.NormalizedProduct{
		ID:                    resolvedBarcode,
		Barcode:               product.StringPtr(resolvedBarcode),
		Name:                  name,
		Brand:                 product.StringPtr(nonEmpty(p.Brands)),
		ImageURL:              product.StringPtr(nonEmpty(p.ImageFrontSmallURL)),
		IngredientText:        ingredientText,
		IngredientTags:        stringSlice(p.IngredientsTags),
		CategoryTags:          categoryTags,
		Additives:             stringSlice(p.AdditivesTags),
		Allergens:             stringSlice(p.AllergensTags),
		Category:              product.ProductCategoryFood,
		Source:                product.ScanSourceOpenFoodFacts,
		Nutrition:             nutrition,
		IngredientsProvenance: product.IngredientProvenanceAPI,
		CapturedAt:            time.Now().UTC(),
	}
}

func nutritionSnapshot(p offProduct) *product.NutritionSnapshot {
	grade := nonEmpty(p.NutriscoreGrade)
	if grade == "" {
		grade = nonEmpty(p.NutritionGradeFR)
	}
	eco := nonEmpty(p.EcoScoreGrade)
	snapshot := product.NutritionSnapshot{
		EnergyKcalPer100g:   numberValue(p.Nutriments["energy-kcal_100g"]),
		SugarsPer100g:       numberValue(p.Nutriments["sugars_100g"]),
		SaturatedFatPer100g: numberValue(p.Nutriments["saturated-fat_100g"]),
		FiberPer100g:        numberValue(p.Nutriments["fiber_100g"]),
		ProteinPer100g:      numberValue(p.Nutriments["proteins_100g"]),
		SaltPer100g:         numberValue(p.Nutriments["salt_100g"]),
		NutritionGrade:      product.StringPtr(grade),
		NovaGroup:           p.NovaGroup,
		EcoScoreGrade:       product.StringPtr(eco),
	}
	if !snapshot.HasAnyValue() {
		return nil
	}
	return &snapshot
}

func numberValue(value any) *float64 {
	switch typed := value.(type) {
	case float64:
		return &typed
	case int:
		value := float64(typed)
		return &value
	case string:
		parsed, err := strconv.ParseFloat(strings.ReplaceAll(typed, ",", "."), 64)
		if err == nil {
			return &parsed
		}
	}
	return nil
}

func preferredCandidate(candidates []product.NormalizedProduct) *product.NormalizedProduct {
	if len(candidates) == 0 {
		return nil
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		if len(candidates[i].IngredientText) == len(candidates[j].IngredientText) {
			return candidates[i].Source < candidates[j].Source
		}
		return len(candidates[i].IngredientText) > len(candidates[j].IngredientText)
	})
	return &candidates[0]
}

func rebaseProduct(value product.NormalizedProduct, scannedBarcode string) product.NormalizedProduct {
	if value.Barcode != nil && *value.Barcode == scannedBarcode {
		return value
	}
	value.Barcode = product.StringPtr(scannedBarcode)
	return value
}

func resolvedName(primaryName, secondaryName, genericName *string, ingredientText string, categoryTags []string) string {
	for _, candidate := range []*string{primaryName, secondaryName, genericName} {
		if candidate != nil {
			if value := nonEmpty(candidate); value != "" {
				return value
			}
		}
	}
	if ingredientName := singleIngredientDisplayName(ingredientText); ingredientName != "" {
		return ingredientName
	}
	if categoryName := humanizedCategoryName(categoryTags); categoryName != "" {
		return categoryName
	}
	return "Unknown Product"
}

func singleIngredientDisplayName(ingredientText string) string {
	parts := strings.Split(ingredientText, ",")
	var values []string
	for _, part := range parts {
		value := strings.TrimSpace(part)
		if value != "" {
			values = append(values, value)
		}
	}
	if len(values) != 1 || len(values[0]) > 40 {
		return ""
	}
	return sentenceCase(whitespace(values[0]))
}

func humanizedCategoryName(tags []string) string {
	for _, tag := range tags {
		raw := tag
		if parts := strings.SplitN(tag, ":", 2); len(parts) == 2 {
			raw = parts[1]
		}
		formatted := strings.TrimSpace(strings.ReplaceAll(raw, "-", " "))
		if formatted == "" || formatted == "fruits and vegetables" || formatted == "foods" {
			continue
		}
		return sentenceCase(formatted)
	}
	return ""
}

func sentenceCase(value string) string {
	if value == "" {
		return value
	}
	return strings.ToUpper(value[:1]) + value[1:]
}

func whitespace(value string) string {
	return strings.Join(strings.Fields(value), " ")
}

func nonEmpty(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func stringSlice(values []string) []string {
	if values == nil {
		return []string{}
	}
	return values
}

func displaySource(source product.ScanSource) string {
	switch source {
	case product.ScanSourceOpenFoodFacts:
		return "Open Food Facts"
	case product.ScanSourceOpenBeautyFacts:
		return "Open Beauty Facts"
	case product.ScanSourceUSDA:
		return "USDA"
	case product.ScanSourceOCR:
		return "OCR"
	case product.ScanSourceCache:
		return "Cached"
	default:
		return string(source)
	}
}

func max(lhs, rhs int) int {
	if lhs > rhs {
		return lhs
	}
	return rhs
}

func min(lhs, rhs int) int {
	if lhs < rhs {
		return lhs
	}
	return rhs
}
