package lab

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"time"

	"aurora/internal/execx"
)

var nameRE = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`)

var (
	wgDirs    = []string{"/etc/wireguard"}
	awgDirs   = []string{"/etc/amnesia", "/etc/amnezia"}
	vlessDirs = []string{
		filepath.Join(execx.Home(), ".config/vless"),
		"/etc/amnesia/vless",
	}
)

const timeout2s = 2 * time.Second

type tunnelRow struct {
	Name   string `json:"name"`
	Label  string `json:"label"`
	Folder string `json:"folder"`
	Up     bool   `json:"up"`
	Path   string `json:"path,omitempty"`
	Kind   string `json:"kind,omitempty"`
}

func ifaceUp(name string) bool {
	code, _, _ := run(timeout2s, "ip", "link", "show", "dev", name)
	return code == 0
}

func configs(dirs []string) []tunnelRow {
	seen := map[string]bool{}
	var out []tunnelRow
	for _, directory := range dirs {
		ents, err := os.ReadDir(directory)
		if err != nil {
			continue
		}
		names := make([]string, 0, len(ents))
		for _, e := range ents {
			names = append(names, e.Name())
		}
		sort.Strings(names)
		for _, filename := range names {
			if !stringsHasSuffix(filename, ".conf") {
				continue
			}
			name := filename[:len(filename)-5]
			if !nameRE.MatchString(name) || seen[name] {
				continue
			}
			seen[name] = true
			path := filepath.Join(directory, filename)
			label, folder := confMeta(path)
			out = append(out, tunnelRow{
				Name:   name,
				Label:  orDefault(label, name),
				Folder: folder,
				Up:     ifaceUp(name),
				Path:   path,
			})
		}
	}
	return out
}

func stringsHasSuffix(s, suf string) bool {
	return len(s) >= len(suf) && s[len(s)-len(suf):] == suf
}

func orDefault(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
