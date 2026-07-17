package grpc

import (
	"errors"
	"testing"

	"github.com/yucai/server/internal/backup/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// TestMapError 锁定 backup handler mapError 的 sentinel → gRPC code 映射。
// 防御:将来新增 sentinel error 忘加 case 会静默落 codes.Internal → client 只见
// 通用消息。表驱动覆盖所有现有 case + unknown default。
func TestMapError(t *testing.T) {
	unexpected := errors.New("some unexpected failure")
	cases := []struct {
		name string
		in   error
		want codes.Code
	}{
		{"checksum mismatch → FailedPrecondition", domain.ErrChecksumMismatch, codes.FailedPrecondition},
		{"format outdated → FailedPrecondition", domain.ErrBackupFormatOutdated, codes.FailedPrecondition},
		{"password required → InvalidArgument", domain.ErrPasswordRequired, codes.InvalidArgument},
		{"password on plaintext → InvalidArgument", domain.ErrPasswordOnPlaintext, codes.InvalidArgument},
		{"wrong password → InvalidArgument", domain.ErrWrongPassword, codes.InvalidArgument},
		{"unknown error → Internal", unexpected, codes.Internal},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := status.Code(mapError(c.in))
			if got != c.want {
				t.Errorf("mapError(%v) code = %v, want %v", c.in, got, c.want)
			}
		})
	}
}
