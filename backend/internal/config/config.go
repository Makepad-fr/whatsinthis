package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	HTTPAddr        string
	DatabaseURL     string
	USDAAPIKey      string
	UserAgent       string
	CacheTTL        time.Duration
	SimilarCacheTTL time.Duration
	ProviderTimeout time.Duration
	DBMaxOpenConns  int
	DBMaxIdleConns  int
	DBConnLifetime  time.Duration
	DBConnIdleTime  time.Duration
}

func Load() (Config, error) {
	databaseURL, err := valueOrFile("WHATSINTHIS_DATABASE_URL", "WHATSINTHIS_DATABASE_URL_FILE")
	if err != nil {
		return Config{}, err
	}
	if databaseURL == "" {
		return Config{}, errors.New("WHATSINTHIS_DATABASE_URL or WHATSINTHIS_DATABASE_URL_FILE is required")
	}

	usdaAPIKey, err := valueOrFile("WHATSINTHIS_USDA_API_KEY", "WHATSINTHIS_USDA_API_KEY_FILE")
	if err != nil {
		return Config{}, err
	}

	cacheTTL, err := envDuration("WHATSINTHIS_PRODUCT_CACHE_TTL", 30*24*time.Hour)
	if err != nil {
		return Config{}, err
	}
	similarCacheTTL, err := envDuration("WHATSINTHIS_SIMILAR_CACHE_TTL", 24*time.Hour)
	if err != nil {
		return Config{}, err
	}
	providerTimeout, err := envDuration("WHATSINTHIS_PROVIDER_TIMEOUT", 6*time.Second)
	if err != nil {
		return Config{}, err
	}
	dbMaxOpenConns, err := envInt("WHATSINTHIS_DB_MAX_OPEN_CONNS", 20)
	if err != nil {
		return Config{}, err
	}
	dbMaxIdleConns, err := envInt("WHATSINTHIS_DB_MAX_IDLE_CONNS", 10)
	if err != nil {
		return Config{}, err
	}
	dbConnLifetime, err := envDuration("WHATSINTHIS_DB_CONN_MAX_LIFETIME", 30*time.Minute)
	if err != nil {
		return Config{}, err
	}
	dbConnIdleTime, err := envDuration("WHATSINTHIS_DB_CONN_MAX_IDLE_TIME", 5*time.Minute)
	if err != nil {
		return Config{}, err
	}

	return Config{
		HTTPAddr:        envString("WHATSINTHIS_HTTP_ADDR", ":8080"),
		DatabaseURL:     databaseURL,
		USDAAPIKey:      usdaAPIKey,
		UserAgent:       envString("WHATSINTHIS_USER_AGENT", "WhatsInThis/1.0 (backend)"),
		CacheTTL:        cacheTTL,
		SimilarCacheTTL: similarCacheTTL,
		ProviderTimeout: providerTimeout,
		DBMaxOpenConns:  dbMaxOpenConns,
		DBMaxIdleConns:  dbMaxIdleConns,
		DBConnLifetime:  dbConnLifetime,
		DBConnIdleTime:  dbConnIdleTime,
	}, nil
}

func valueOrFile(valueEnv, fileEnv string) (string, error) {
	if value := strings.TrimSpace(os.Getenv(valueEnv)); value != "" {
		return value, nil
	}

	path := strings.TrimSpace(os.Getenv(fileEnv))
	if path == "" {
		return "", nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("read %s: %w", fileEnv, err)
	}
	return strings.TrimSpace(string(data)), nil
}

func envString(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func envDuration(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}
	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be a valid duration: %w", key, err)
	}
	return duration, nil
}

func envInt(key string, fallback int) (int, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be a valid integer: %w", key, err)
	}
	if parsed < 0 {
		return 0, fmt.Errorf("%s must be non-negative", key)
	}
	return parsed, nil
}
