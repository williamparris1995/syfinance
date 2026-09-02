.PHONY: all generate build test test-unit lint proto gen-dart clean docker-up docker-down flutter-get flutter-build-runner flutter-test windows-installer client-e2e client-e2e-ui validate

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
	MSYS2_ARG_CONV_EXCL="/D" "$(ISCC)" /DAppVersion=$(APP_VERSION) client/packaging/yucai.iss
	@echo "installer ready: client/dist/yucai-setup-$(APP_VERSION).exe"

# Full validation
validate: lint test flutter-test ## Run all checks
	@echo "All checks passed!"

# R7 验收工作流(user 要求):种子测试数据 → 全模块 E2E → 测完即删。
# 独立测试库(yucai_test.db),用户真实库(yucai.db)永不被触碰;
# 每个文件单独跑(Windows 桌面集成测试设备启动竞争),跑前杀残留实例。
# F6 双入口(ADR-1):E2E_FILES = 管道链路默认回归;E2E_UI_FILES = UI 链手动按需(T4 填充)。
# 新链路文件按追加顺序排列(串行执行序),后续任务持续在此列表尾部追加。
E2E_FILES := integration_test/app_pages_test.dart integration_test/linked_transactions_test.dart integration_test/full_audit_test.dart integration_test/link_receivable_collect_test.dart integration_test/link_subscription_template_test.dart integration_test/link_budget_goal_test.dart integration_test/link_tag_report_test.dart integration_test/link_holding_buy_test.dart integration_test/link_mutation_cascade_test.dart integration_test/link_backup_roundtrip_test.dart

# UI 链文件(T4 十文件,design HLD「UI 链文件」;一链一文件,不进默认回归;
# fix round 1 尾追加 ui_template_record —— FR-12「手动触发记一笔」枚举项补齐)。
E2E_UI_FILES := integration_test/ui_boot_subscription_test.dart integration_test/ui_record_form_test.dart integration_test/ui_transfer_form_test.dart integration_test/ui_collect_form_test.dart integration_test/ui_buy_form_test.dart integration_test/ui_contribution_form_test.dart integration_test/ui_budget_page_test.dart integration_test/ui_tag_page_test.dart integration_test/ui_backup_entry_test.dart integration_test/ui_list_filter_test.dart integration_test/ui_template_record_test.dart

# F= 单文件精准重跑(两入口通用,F 非空则只跑该文件),例:
#   make client-e2e F=integration_test/link_budget_goal_test.dart
#   make client-e2e-ui F=integration_test/ui_tag_page_test.dart
client-e2e: FILES := $(if $(F),$(F),$(E2E_FILES))
client-e2e: ## 管道链路 E2E 默认回归(种子注入→断言→测试库删除);F= 单文件精准重跑
	@for f in $(FILES); do 		powershell -NoProfile -Command "Get-Process yucai_client -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null; 		echo "=== $$f ==="; 		cd client && flutter test $$f -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db || exit 1; 		cd ..; 	done
	@echo "client E2E: all suites passed (test DB auto-deleted)"

client-e2e-ui: FILES := $(if $(F),$(F),$(E2E_UI_FILES))
client-e2e-ui: ## UI 链 E2E 手动入口(E2E_UI_FILES 十文件串行);列表为空仅提示不报错;F= 单文件精准重跑
	@if [ -z "$(strip $(FILES))" ]; then echo "no UI files yet"; else 	for f in $(FILES); do 		powershell -NoProfile -Command "Get-Process yucai_client -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null; 		echo "=== $$f ==="; 		cd client && flutter test $$f -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db || exit 1; 		cd ..; 	done; 	echo "client E2E UI: all suites passed (test DB auto-deleted)"; fi
