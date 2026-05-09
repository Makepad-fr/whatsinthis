package source

import (
	"sort"
	"strings"

	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
)

type recommendationSearchTarget struct {
	slug        string
	debugLabel  string
	searchValue string
}

func recommendationSearchTargets(value product.NormalizedProduct) []recommendationSearchTarget {
	targets := preferredRecommendationSearchTargets(value)
	if len(targets) == 0 {
		for _, tag := range rankedRecommendationCategoryTags(value.CategoryTags) {
			target := recommendationSearchTargetFromTag(tag)
			if target.slug != "" {
				targets = append(targets, target)
			}
			if len(targets) >= 3 {
				break
			}
		}
	}

	seen := map[string]struct{}{}
	result := make([]recommendationSearchTarget, 0, 3)
	for _, target := range targets {
		if isGenericRecommendationCategorySlug(target.slug) {
			continue
		}
		if _, ok := seen[target.slug]; ok {
			continue
		}
		seen[target.slug] = struct{}{}
		result = append(result, target)
		if len(result) >= 3 {
			break
		}
	}
	return result
}

func preferredRecommendationSearchTargets(value product.NormalizedProduct) []recommendationSearchTarget {
	context := product.NormalizedName(strings.Join(append([]string{value.Name}, append(value.CategoryTags, value.IngredientText)...), " "))

	if matchesAny([]string{"confiture", "jam", "jams", "marmalade", "jelly", "preserve", "preserves"}, context) {
		return []recommendationSearchTarget{
			newRecommendationSearchTarget("jams", "jams"),
			newRecommendationSearchTarget("fruit-preserves", "fruit preserves"),
		}
	}
	if matchesAny([]string{"hazelnut spread", "chocolate spread", "cocoa and hazelnut", "pate a tartiner", "sweet spread", "sweet spreads"}, context) {
		return []recommendationSearchTarget{
			newRecommendationSearchTarget("cocoa-and-hazelnuts-spreads", "cocoa and hazelnuts spreads"),
			newRecommendationSearchTarget("sweet-spreads", "sweet spreads"),
		}
	}
	if matchesAny([]string{"yogurt", "yoghurt", "yaourt"}, context) {
		return []recommendationSearchTarget{newRecommendationSearchTarget("yogurts", "yogurts")}
	}
	if matchesAny([]string{"biscuit", "biscuits", "cookie", "cookies"}, context) {
		return []recommendationSearchTarget{
			newRecommendationSearchTarget("biscuits", "biscuits"),
			newRecommendationSearchTarget("cookies", "cookies"),
		}
	}
	if matchesAny([]string{"cereal", "cereals", "granola", "muesli"}, context) {
		return []recommendationSearchTarget{
			newRecommendationSearchTarget("breakfast-cereals", "breakfast cereals"),
			newRecommendationSearchTarget("granolas", "granolas"),
			newRecommendationSearchTarget("mueslis", "mueslis"),
		}
	}
	if matchesAny([]string{"soda", "cola", "soft drink", "soft drinks"}, context) {
		return []recommendationSearchTarget{
			newRecommendationSearchTarget("sodas", "sodas"),
			newRecommendationSearchTarget("soft-drinks", "soft drinks"),
		}
	}
	return nil
}

func rankedRecommendationCategoryTags(tags []string) []string {
	result := make([]string, 0, len(tags))
	for _, tag := range tags {
		if !strings.Contains(tag, ":") || isGenericRecommendationCategoryTag(tag) {
			continue
		}
		result = append(result, tag)
	}
	sort.Slice(result, func(i, j int) bool {
		return categorySpecificityScore(result[i]) > categorySpecificityScore(result[j])
	})
	return result
}

func categorySpecificityScore(tag string) int {
	value := tag
	if parts := strings.SplitN(tag, ":", 2); len(parts) == 2 {
		value = parts[1]
	}
	tokenCount := len(strings.Fields(strings.ReplaceAll(value, "-", " ")))
	return len(value) + strings.Count(value, "-")*8 - tokenCount*3
}

func recommendationSearchTargetFromTag(tag string) recommendationSearchTarget {
	raw := tag
	if parts := strings.SplitN(tag, ":", 2); len(parts) == 2 {
		raw = parts[1]
	}
	slug := strings.ToLower(strings.TrimSpace(raw))
	if slug == "" {
		return recommendationSearchTarget{}
	}
	return newRecommendationSearchTarget(slug, strings.ReplaceAll(raw, "-", " "))
}

func newRecommendationSearchTarget(slug, debugLabel string) recommendationSearchTarget {
	return recommendationSearchTarget{slug: slug, debugLabel: debugLabel, searchValue: debugLabel}
}

func isGenericRecommendationCategorySlug(slug string) bool {
	generic := map[string]struct{}{
		"foods":                             {},
		"foods-and-beverages":               {},
		"beverages":                         {},
		"plant-based-foods":                 {},
		"plant-based-foods-and-beverages":   {},
		"fruits-and-vegetables-based-foods": {},
		"fruit-and-vegetable-preserves":     {},
		"plant-based-spreads":               {},
		"groceries":                         {},
	}
	_, ok := generic[slug]
	return ok
}

func isGenericRecommendationCategoryTag(tag string) bool {
	value := tag
	if parts := strings.SplitN(tag, ":", 2); len(parts) == 2 {
		value = parts[1]
	}
	value = product.NormalizedName(value)
	genericPhrases := []string{
		"foods",
		"foods and beverages",
		"beverages",
		"plant based foods",
		"plant based foods and beverages",
		"fruits and vegetables based foods",
		"fruit and vegetable preserves",
		"plant based spreads",
		"groceries",
	}
	for _, phrase := range genericPhrases {
		if value == phrase || strings.HasPrefix(value, phrase+" ") {
			return true
		}
	}
	return false
}

func matchesAny(candidates []string, text string) bool {
	for _, candidate := range candidates {
		if strings.Contains(text, candidate) {
			return true
		}
	}
	return false
}
