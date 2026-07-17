package domain

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

// TenantDataPort 是各业务模块提供给 backup 的导出/导入/清空 port。
// 各模块(backup 不 import 它们)在 adapter/driven/exporter/ 下实现此接口,
// wire 注入到 backup Service 的 []TenantDataPort。对齐 networth/goal port 惯例。
type TenantDataPort interface {
	// Name 返回模块标识(envelope.Modules 的 key,如 "account"/"transaction")。
	Name() string
	// Export 导出 tenant 全量业务数据为 JSON(模块自定义结构)。
	Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error)
	// Import 把 envelope.Modules[Name()] 的 JSON 写回 DB(restore,前置 Purge 已清)。
	Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error
	// Purge 删除 tenant 该模块全部业务数据(restore 前清空,避 ID 冲突)。
	Purge(ctx context.Context, tenantID uuid.UUID) error
}

// BackupEnvelope 是备份文件的 JSON 顶层结构。
type BackupEnvelope struct {
	Version   int                        `json:"version"`
	TenantID  uuid.UUID                  `json:"tenant_id"`
	CreatedAt time.Time                  `json:"created_at"`
	Modules   map[string]json.RawMessage `json:"modules"`
}

var (
	ErrPasswordRequired    = errors.New("password required for encrypted backup")
	ErrPasswordOnPlaintext = errors.New("password not allowed for plaintext backup")
	ErrChecksumMismatch    = errors.New("backup checksum mismatch")
)
