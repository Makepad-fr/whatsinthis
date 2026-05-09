package source

type offProductResponse struct {
	Status  int         `json:"status"`
	Product *offProduct `json:"product"`
}

type offSearchResponse struct {
	Products []offProduct `json:"products"`
}

type offProduct struct {
	Code                   *string        `json:"code"`
	ProductName            *string        `json:"product_name"`
	AbbreviatedProductName *string        `json:"abbreviated_product_name"`
	GenericName            *string        `json:"generic_name"`
	Brands                 *string        `json:"brands"`
	ImageFrontSmallURL     *string        `json:"image_front_small_url"`
	IngredientsText        *string        `json:"ingredients_text"`
	IngredientsTextEN      *string        `json:"ingredients_text_en"`
	IngredientsTags        []string       `json:"ingredients_tags"`
	AllergensTags          []string       `json:"allergens_tags"`
	AdditivesTags          []string       `json:"additives_tags"`
	CategoriesTags         []string       `json:"categories_tags"`
	Nutriments             map[string]any `json:"nutriments"`
	NutritionGradeFR       *string        `json:"nutrition_grade_fr"`
	NutriscoreGrade        *string        `json:"nutriscore_grade"`
	NovaGroup              *int           `json:"nova_group"`
	EcoScoreGrade          *string        `json:"ecoscore_grade"`
}

type obfProductResponse struct {
	Status  int         `json:"status"`
	Product *obfProduct `json:"product"`
}

type obfProduct struct {
	ProductName            *string  `json:"product_name"`
	AbbreviatedProductName *string  `json:"abbreviated_product_name"`
	GenericName            *string  `json:"generic_name"`
	Brands                 *string  `json:"brands"`
	ImageFrontSmallURL     *string  `json:"image_front_small_url"`
	IngredientsText        *string  `json:"ingredients_text"`
	IngredientsTags        []string `json:"ingredients_tags"`
	CategoriesTags         []string `json:"categories_tags"`
}

type usdaSearchResponse struct {
	Foods []usdaFood `json:"foods"`
}

type usdaFood struct {
	FDCID        int    `json:"fdcId"`
	Description  string `json:"description"`
	BrandOwner   string `json:"brandOwner"`
	Ingredients  string `json:"ingredients"`
	GTINUPC      string `json:"gtinUpc"`
	FoodCategory string `json:"foodCategory"`
}
