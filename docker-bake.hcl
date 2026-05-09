variable "IMAGE_NAME" {
  default = "ghcr.io/makepad-fr/whatsinthis-backend"
}

variable "REPOSITORY" {
  default = "Makepad-fr/whatsinthis"
}

variable "GO_VERSION" {
  default = "1.26"
}

variable "DHI_STATIC_TAG" {
  default = "20250419-debian13"
}

variable "BUILD_DATE" {
  default = "1970-01-01T00:00:00Z"
}

variable "VCS_REF" {
  default = "local"
}

variable "VERSION" {
  default = "local"
}

variable "LOCAL_CACHE_DIR" {
  default = ".cache/buildx"
}

target "common" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    BUILD_DATE     = "${BUILD_DATE}"
    DHI_STATIC_TAG = "${DHI_STATIC_TAG}"
    GO_VERSION     = "${GO_VERSION}"
    VCS_REF        = "${VCS_REF}"
    VERSION        = "${VERSION}"
  }
  labels = {
    "org.opencontainers.image.created"  = "${BUILD_DATE}"
    "org.opencontainers.image.revision" = "${VCS_REF}"
    "org.opencontainers.image.source"   = "https://github.com/${REPOSITORY}"
    "org.opencontainers.image.version"  = "${VERSION}"
  }
}

target "backend-test" {
  inherits = ["common"]
  target   = "backend-test"
}

target "backend-build" {
  inherits = ["common"]
  target   = "backend-build"
}

target "runtime" {
  inherits = ["common"]
  target   = "runtime"
  tags     = ["${IMAGE_NAME}:local"]
}

target "backend-test-local-cache" {
  cache-from = ["type=local,src=${LOCAL_CACHE_DIR}/backend/test"]
  cache-to   = ["type=local,dest=${LOCAL_CACHE_DIR}/backend/test,mode=max"]
}

target "backend-build-local-cache" {
  cache-from = ["type=local,src=${LOCAL_CACHE_DIR}/backend/build"]
  cache-to   = ["type=local,dest=${LOCAL_CACHE_DIR}/backend/build,mode=max"]
}

target "runtime-local-cache" {
  cache-from = ["type=local,src=${LOCAL_CACHE_DIR}/backend/runtime"]
  cache-to   = ["type=local,dest=${LOCAL_CACHE_DIR}/backend/runtime,mode=max"]
}

target "backend-test-local" {
  inherits = ["backend-test", "backend-test-local-cache"]
}

target "backend-build-local" {
  inherits = ["backend-build", "backend-build-local-cache"]
}

target "local" {
  inherits = ["runtime", "runtime-local-cache"]
  load     = true
  tags     = ["${IMAGE_NAME}:local", "whatsinthis-backend:local"]
}

target "publish" {
  inherits = ["runtime"]
  push     = true
  tags     = ["${IMAGE_NAME}:canary", "${IMAGE_NAME}:${VERSION}"]
}

group "checks-local" {
  targets = ["backend-test-local", "backend-build-local"]
}
