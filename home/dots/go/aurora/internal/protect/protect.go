package protect

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"aurora/internal/execx"
)

// Keep Steam / NVIDIA shader caches on durable /home storage.
// Never delete cache trees. Never replace a larger cache with a smaller one.

func cacheHome() string {
	if d := os.Getenv("XDG_CACHE_HOME"); d != "" {
		return d
	}
	return filepath.Join(execx.Home(), ".cache")
}

func linkLarger(src, dst string) {
	st, err := os.Stat(src)
	if err != nil || st.IsDir() {
		return
	}
	_ = os.MkdirAll(filepath.Dir(dst), 0o755)
	var db int64
	if dstSt, err := os.Stat(dst); err == nil && !dstSt.IsDir() {
		db = dstSt.Size()
	}
	if db >= 4096 {
		return
	}
	if st.Size() <= db {
		return
	}
	in, err := os.Open(src)
	if err != nil {
		return
	}
	defer in.Close()
	tmp := dst + ".tmp"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return
	}
	_, copyErr := io.Copy(out, in)
	_ = out.Close()
	if copyErr != nil {
		_ = os.Remove(tmp)
		return
	}
	_ = os.Rename(tmp, dst)
}

func dirBytes(root string) int64 {
	var total int64
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		total += info.Size()
		return nil
	})
	return total
}

func keepNvidia(src, destRoot string) {
	st, err := os.Stat(src)
	if err != nil || !st.IsDir() {
		return
	}
	_ = os.MkdirAll(destRoot, 0o755)
	_ = os.WriteFile(filepath.Join(destRoot, ".aurora-no-delete"), []byte("protected\n"), 0o644)
	_ = filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if filepath.Ext(path) != ".bin" {
			return nil
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return nil
		}
		linkLarger(path, filepath.Join(destRoot, rel))
		return nil
	})
	total := dirBytes(destRoot)
	frozen := filepath.Join(destRoot, ".frozen")
	if total >= 2147483648 {
		_ = os.WriteFile(frozen, []byte("frozen\n"), 0o644)
	} else {
		_ = os.Remove(frozen)
	}
}

func stamp(path string) {
	_ = os.MkdirAll(path, 0o755)
	_ = os.WriteFile(filepath.Join(path, ".aurora-no-delete"), []byte("protected\n"), 0o644)
}

func Main(args []string) int {
	xh := cacheHome()
	shaderRoot := filepath.Join(xh, "steam-shadercache")
	dxvkRoot := filepath.Join(xh, "dxvk")
	terrariaNV := filepath.Join(xh, "nvidia", "terraria")
	albionNV := filepath.Join(xh, "nvidia", "albion")

	for _, d := range []string{
		shaderRoot, dxvkRoot,
		filepath.Join(shaderRoot, "761890"),
		filepath.Join(shaderRoot, "105600"),
		terrariaNV, albionNV,
	} {
		_ = os.MkdirAll(d, 0o755)
	}
	_ = os.Chmod(shaderRoot, 0o700)
	_ = os.Chmod(dxvkRoot, 0o700)

	keepNvidia(filepath.Join(shaderRoot, "105600", "nvidiav1"), terrariaNV)
	keepNvidia(filepath.Join(shaderRoot, "761890", "nvidiav1"), albionNV)
	keepNvidia("/steam/steamapps/shadercache/105600/nvidiav1", terrariaNV)
	keepNvidia("/steam/steamapps/shadercache/761890/nvidiav1", albionNV)

	stamp(shaderRoot)
	stamp(dxvkRoot)
	stamp(terrariaNV)
	stamp(albionNV)

	fmt.Printf("shader-protect: terraria+albion ok path=%s\n", shaderRoot)
	return 0
}
