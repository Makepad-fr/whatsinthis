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

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("ping database: %v", err)
	}
	if err := database.Migrate(ctx, db); err != nil {
		log.Fatalf("migrate database: %v", err)
	}

	store := database.NewStore(db, cfg.CacheTTL, cfg.SimilarCacheTTL)
	if err := glossary.Seed(ctx, store); err != nil {
		log.Fatalf("seed glossary: %v", err)
	}

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
