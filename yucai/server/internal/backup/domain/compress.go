package domain

import (
	"bytes"
	"compress/gzip"
	"errors"
	"io"
)

// ErrBackupFormatOutdated 旧格式(未 gzip)备份无法 restore(不向后兼容)。
var ErrBackupFormatOutdated = errors.New("backup format outdated, please recreate")

// Compress gzip-压缩(所有 backup 统一压缩,不向后兼容)。
func Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	gw := gzip.NewWriter(&buf)
	if _, err := gw.Write(data); err != nil {
		return nil, err
	}
	if err := gw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// Decompress gunzip;非 gzip header(旧格式)→ ErrBackupFormatOutdated。
func Decompress(data []byte) ([]byte, error) {
	gr, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		// gzip header 错误 = 旧未压缩备份(不向后兼容,友好提示重建)。
		return nil, ErrBackupFormatOutdated
	}
	defer gr.Close()
	return io.ReadAll(gr)
}
