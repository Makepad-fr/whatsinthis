# Repository Conventions

## Git

- Never push directly to `main`; create a separate `codex/*` branch for implementation work.
- Use small atomic conventional commits.
- Sign every commit with GPG key `5E39701089A20771`.

## Backend

- The Go backend lives under `backend/`.
- Go code may use the standard library and `github.com/lib/pq` only.
- Product lookup, similar-product search, product cache, and ingredient glossary storage belong in the backend.
- PostgreSQL is the source of truth for backend cache and glossary data.
- Local development uses a local PostgreSQL container from compose.
- Production and canary use existing PostgreSQL instances via Docker Swarm secrets.

## Docker And BuildKit

- Use `docker buildx bake checks-local` for local backend Docker validation.
- Use `docker buildx bake local` to build the local runtime image.
- Local BuildKit cache lives under `.cache/buildx/`.
- CI uses registry cache at `ghcr.io/makepad-fr/whatsinthis-backend:buildcache`.
- Dockerfiles must stay minimal, avoid Alpine, use Docker Hardened Images for build stages, and use a distroless/static nonroot final runtime.
- Log in to `dhi.io` before building if Docker Hardened Images are not already available locally.

## Compose And Deploy

- Base local compose files are `compose.yml` and `compose.db.yml`.
- Local overrides live under `envs/local/`.
- Swarm deployment files live under `deploy/` and `deploy/envs/<environment>/`.
- Remote deploys must render compose files with `docker compose config` before `docker stack deploy`.
- Runtime credentials must be mounted as Docker secrets and consumed with `_FILE` environment variables.

## Releases

- Backend canary images are published as `${GITHUB_SHA}` and `canary`.
- Backend release tags use `backend/vX.Y.Z`; the GHCR image tag strips the prefix to `X.Y.Z`.
- iOS release tags use `ios/vX.Y.Z`; TestFlight archives must set `MARKETING_VERSION=X.Y.Z`.
- TestFlight builds must receive `WHATSINTHIS_BACKEND_BASE_URL` from GitHub environment vars or secrets.
