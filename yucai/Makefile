.PHONY: all generate build test test-unit lint proto gen-dart clean docker-up docker-down flutter-get flutter-build-runner flutter-test windows-installer validate

# Go server
SERVER_DIR := server

generate: ## Generate entGo + Wire code
	cd $(SERVER_DIR) && go generate ./...

build: generate ## Build Go server binary
	cd $(SERVER_DIR) && go build -o bin/server ./cmd/server

test: ## Run Go tests
	cd $(SERVER_DIR) && go test ./... -v -count=1

test-unit: ## Run unit tests only
	cd $(SERVER_DIR) && go test ./internal/... -v -short -count=1

lint: ## Run golangci-lint
	cd $(SERVER_DIR) && golangci-lint run ./...

proto: ## Generate Protobuf stubs (Go + Dart)
	buf generate

gen-dart: ## Generate Flutter Dart protobuf stubs via manual protoc
	cd proto && bash gen-dart.sh

clean: ## Clean build artifacts
	rm -rf $(SERVER_DIR)/bin
	rm -rf $(SERVER_DIR)/internal/proto
	rm -rf client/lib/proto

# Docker
docker-up: ## Start infrastructure services
	docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.dev.yml up -d

docker-down: ## Stop infrastructure services
	docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.dev.yml down

# Flutter
flutter-get: ## Install Flutter dependencies
	cd client && flutter pub get

flutter-build-runner: ## Run Flutter code generation
	cd client && dart run build_runner build --delete-conflicting-outputs

flutter-test: ## Run Flutter tests
	cd client && flutter test

ISCC := $(LOCALAPPDATA)/Programs/Inno Setup 6/ISCC.exe

windows-installer: ## Build Windows installer (flutter release + Inno Setup); 版本取自 client/pubspec.yaml
	cd client && flutter build windows --release
	$(eval APP_VERSION := $(shell grep -m1 '^version' client/pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1))
	"$(ISCC)" /DAppVersion=$(APP_VERSION) client/packaging/yucai.iss
	@echo "installer ready: client/dist/yucai-setup-$(APP_VERSION).exe"

# Full validation
validate: lint test flutter-test ## Run all checks
	@echo "All checks passed!"
