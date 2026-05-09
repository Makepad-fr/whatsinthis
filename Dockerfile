# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.25
ARG DHI_STATIC_TAG=20250419-debian13

FROM dhi.io/golang:${GO_VERSION}-debian13-dev AS backend-base
WORKDIR /src

COPY backend/go.mod backend/go.sum ./backend/
RUN --mount=type=cache,target=/root/go/pkg/mod \
  cd backend && go mod download

COPY backend ./backend

FROM backend-base AS backend-test
RUN --mount=type=cache,target=/root/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  cd backend && go test ./...

FROM backend-base AS backend-build
ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN --mount=type=cache,target=/root/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  cd backend && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
  go build -trimpath -ldflags="-s -w" -o /out/whatsinthis-backend .

FROM dhi.io/static:${DHI_STATIC_TAG} AS runtime
ARG BUILD_DATE=1970-01-01T00:00:00Z
ARG VCS_REF=local
ARG VERSION=local
WORKDIR /app

LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.revision=${VCS_REF}
LABEL org.opencontainers.image.version=${VERSION}

COPY --from=backend-build /out/whatsinthis-backend /app/whatsinthis-backend

ENV WHATSINTHIS_HTTP_ADDR=:8080
EXPOSE 8080
ENTRYPOINT ["/app/whatsinthis-backend"]
