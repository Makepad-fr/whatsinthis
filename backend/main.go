package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"

	"github.com/Makepad-fr/whatsinthis/backend/internal/config"
	"github.com/Makepad-fr/whatsinthis/backend/internal/database"
	"github.com/Makepad-fr/whatsinthis/backend/internal/glossary"
	"github.com/Makepad-fr/whatsinthis/backend/internal/product"
	"github.com/Makepad-fr/whatsinthis/backend/internal/server"
	"github.com/Makepad-fr/whatsinthis/backend/internal/source"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	db, err := sql.Open("postgres", cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(cfg.DBMaxOpenConns)
	db.SetMaxIdleConns(cfg.DBMaxIdleConns)
	db.SetConnMaxLifetime(cfg.DBConnLifetime)
	db.SetConnMaxIdleTime(cfg.DBConnIdleTime)

	pingCtx, pingCancel := context.WithTimeout(context.Background(), 5*time.Second)
	if err := db.PingContext(pingCtx); err != nil {
		pingCancel()
		log.Fatalf("ping database: %v", err)
	}
	pingCancel()

	migrateCtx, migrateCancel := context.WithTimeout(context.Background(), 30*time.Second)
	if err := database.Migrate(migrateCtx, db); err != nil {
		migrateCancel()
		log.Fatalf("migrate database: %v", err)
	}
	migrateCancel()

	store := database.NewStore(db, cfg.CacheTTL, cfg.SimilarCacheTTL)
	seedCtx, seedCancel := context.WithTimeout(context.Background(), 30*time.Second)
	if err := glossary.Seed(seedCtx, store); err != nil {
		seedCancel()
		log.Fatalf("seed glossary: %v", err)
	}
	seedCancel()

	service := product.NewService(
		store,
		source.NewClient(source.Config{
			HTTPClient: &http.Client{Timeout: cfg.ProviderTimeout},
			UserAgent:  cfg.UserAgent,
			USDAKey:    cfg.USDAAPIKey,
		}),
	)

	httpServer := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           server.New(service, db),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Printf("listening on %s", cfg.HTTPAddr)
		errCh <- httpServer.ListenAndServe()
	}()

	signalCh := make(chan os.Signal, 1)
	signal.Notify(signalCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-signalCh:
		log.Printf("received %s, shutting down", sig)
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("shutdown server: %v", err)
	}
}
