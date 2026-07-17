package domain

import (
	"bytes"
	"errors"
	"testing"
)

func TestCompressDecompressRoundtrip(t *testing.T) {
	cases := [][]byte{
		[]byte(`{"version":1,"modules":{"account":[{"name":"Cash"}]}}`),
		[]byte(`[]`),
		[]byte(``),
		bytes.Repeat([]byte("abcdefgh"), 1000),
	}
	for i, in := range cases {
		out, err := Compress(in)
		if err != nil {
			t.Fatalf("case %d Compress: %v", i, err)
		}
		back, err := Decompress(out)
		if err != nil {
			t.Fatalf("case %d Decompress: %v", i, err)
		}
		if !bytes.Equal(back, in) {
			t.Fatalf("case %d roundtrip mismatch: got %q want %q", i, back, in)
		}
	}
}

func TestCompressShrinksRepetitiveInput(t *testing.T) {
	in := bytes.Repeat([]byte("abcdefgh"), 1000) // 8000 bytes
	out, err := Compress(in)
	if err != nil {
		t.Fatalf("Compress: %v", err)
	}
	if len(out) >= len(in) {
		t.Fatalf("compressed %d bytes -> %d, want smaller", len(in), len(out))
	}
}

func TestDecompressLegacyFormatErrors(t *testing.T) {
	// 旧未压缩备份(raw JSON,非 gzip)→ 不向后兼容 → ErrBackupFormatOutdated
	legacy := []byte(`{"version":1,"modules":{}}`)
	_, err := Decompress(legacy)
	if !errors.Is(err, ErrBackupFormatOutdated) {
		t.Fatalf("err = %v, want ErrBackupFormatOutdated", err)
	}
}
