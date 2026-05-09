package product

import (
	"regexp"
	"strings"
	"unicode"
)

var nonAlnum = regexp.MustCompile(`[^a-z0-9\s]+`)
var whitespace = regexp.MustCompile(`\s+`)

func NormalizeBarcode(barcode string) string {
	var builder strings.Builder
	for _, r := range barcode {
		if unicode.IsDigit(r) {
			builder.WriteRune(r)
		}
	}
	return builder.String()
}

func LookupCandidates(barcode string) []string {
	barcode = NormalizeBarcode(barcode)
	if barcode == "" {
		return nil
	}
	if len(barcode) == 14 && strings.HasPrefix(barcode, "0") {
		return []string{barcode, barcode[1:]}
	}
	return []string{barcode}
}

func NormalizedName(value string) string {
	value = strings.ToLower(value)
	value = strings.ReplaceAll(value, "-", " ")
	value = nonAlnum.ReplaceAllString(value, " ")
	value = whitespace.ReplaceAllString(value, " ")
	return strings.TrimSpace(value)
}

func DeduplicateProducts(products []NormalizedProduct) []NormalizedProduct {
	seen := map[string]struct{}{}
	result := make([]NormalizedProduct, 0, len(products))
	for _, candidate := range products {
		key := NormalizedName(candidate.Name)
		if candidate.Barcode != nil {
			if barcode := NormalizeBarcode(*candidate.Barcode); barcode != "" {
				key = barcode
			}
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, candidate)
	}
	return result
}

func StringPtr(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}
