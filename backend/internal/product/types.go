package product

import "time"

type ProductCategory string

const (
	ProductCategoryFood    ProductCategory = "food"
	ProductCategoryBeauty  ProductCategory = "beauty"
	ProductCategoryUnknown ProductCategory = "unknown"
)

type ScanSource string

const (
	ScanSourceOpenFoodFacts   ScanSource = "openFoodFacts"
	ScanSourceOpenBeautyFacts ScanSource = "openBeautyFacts"
	ScanSourceUSDA            ScanSource = "usda"
	ScanSourceOCR             ScanSource = "ocr"
	ScanSourceCache           ScanSource = "cache"
)

type IngredientProvenance string

const (
	IngredientProvenanceAPI      IngredientProvenance = "api"
	IngredientProvenanceOCR      IngredientProvenance = "ocr"
	IngredientProvenanceGlossary IngredientProvenance = "glossary"
	IngredientProvenanceInferred IngredientProvenance = "inferred"
)

type NutritionSnapshot struct {
	EnergyKcalPer100g   *float64 `json:"energyKcalPer100g"`
	SugarsPer100g       *float64 `json:"sugarsPer100g"`
	SaturatedFatPer100g *float64 `json:"saturatedFatPer100g"`
	FiberPer100g        *float64 `json:"fiberPer100g"`
	ProteinPer100g      *float64 `json:"proteinPer100g"`
	SaltPer100g         *float64 `json:"saltPer100g"`
	NutritionGrade      *string  `json:"nutritionGrade"`
	NovaGroup           *int     `json:"novaGroup"`
	EcoScoreGrade       *string  `json:"ecoScoreGrade"`
}

func (n NutritionSnapshot) HasAnyValue() bool {
	return n.EnergyKcalPer100g != nil ||
		n.SugarsPer100g != nil ||
		n.SaturatedFatPer100g != nil ||
		n.FiberPer100g != nil ||
		n.ProteinPer100g != nil ||
		n.SaltPer100g != nil ||
		n.NutritionGrade != nil ||
		n.NovaGroup != nil ||
		n.EcoScoreGrade != nil
}

type NormalizedProduct struct {
	ID                    string               `json:"id"`
	Barcode               *string              `json:"barcode"`
	Name                  string               `json:"name"`
	Brand                 *string              `json:"brand"`
	ImageURL              *string              `json:"imageURL"`
	IngredientText        string               `json:"ingredientText"`
	IngredientTags        []string             `json:"ingredientTags"`
	CategoryTags          []string             `json:"categoryTags"`
	Additives             []string             `json:"additives"`
	Allergens             []string             `json:"allergens"`
	Category              ProductCategory      `json:"category"`
	Source                ScanSource           `json:"source"`
	Nutrition             *NutritionSnapshot   `json:"nutrition"`
	OCRConfidence         *float64             `json:"ocrConfidence"`
	IngredientsProvenance IngredientProvenance `json:"ingredientsProvenance"`
	CapturedAt            time.Time            `json:"capturedAt"`
}

type LookupRequest struct {
	Barcode          string `json:"barcode"`
	LocaleIdentifier string `json:"localeIdentifier"`
}

type SimilarProductsRequest struct {
	Product NormalizedProduct `json:"product"`
	Limit   int               `json:"limit"`
}

type LookupResponse struct {
	Product *NormalizedProduct `json:"product"`
	Message *string            `json:"message"`
}

type GlossaryItem struct {
	ID       string          `json:"id"`
	Name     string          `json:"name"`
	Aliases  []string        `json:"aliases"`
	Category ProductCategory `json:"category"`
	Summary  string          `json:"summary"`
	Function string          `json:"function"`
	Caution  bool            `json:"caution"`
	Markers  []string        `json:"markers"`
}
