package cursor

import (
	"encoding/binary"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

func cacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(execx.Home(), ".cache")
	}
	return filepath.Join(base, "aurora")
}

func catalogue() string {
	for _, p := range []string{
		filepath.Join(execx.Home(), "Documents", "projects", "config", "home", "dots", "aurora-qs", "assets", "cursors", "catalogue.json"),
		filepath.Join(execx.Home(), ".config", "quickshell", "assets", "cursors", "catalogue.json"),
	} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func resolveTheme(id, fallback string) string {
	path := catalogue()
	if path == "" {
		return fallback
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	var data any
	if json.Unmarshal(raw, &data) != nil {
		return fallback
	}
	var items []any
	switch t := data.(type) {
	case []any:
		items = t
	case map[string]any:
		if c, ok := t["cursors"].([]any); ok {
			items = c
		}
	}
	for _, it := range items {
		m, ok := it.(map[string]any)
		if !ok {
			continue
		}
		for _, key := range []string{"id", "theme", "name"} {
			if str(m[key]) == id {
				if t := str(m["theme"]); t != "" {
					return t
				}
				if t := str(m["id"]); t != "" {
					return t
				}
				return fallback
			}
		}
	}
	return fallback
}

func str(v any) string {
	s, _ := v.(string)
	return s
}

func findTheme(name string) string {
	home := execx.Home()
	for _, c := range []string{
		filepath.Join(home, ".local", "share", "icons", name),
		filepath.Join(home, ".icons", name),
		filepath.Join(home, "Documents", "projects", "config", "home", "dots", "cursors", "themes", name),
	} {
		if hasCursor(c) {
			return c
		}
	}
	return ""
}

func hasCursor(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, "cursors", "left_ptr")); err == nil {
		return true
	}
	_, err := os.Stat(filepath.Join(dir, "cursors", "default"))
	return err == nil
}

func scanThemes(id, theme string) (string, string) {
	roots := []string{
		filepath.Join(execx.Home(), ".icons"),
		filepath.Join(execx.Home(), ".local", "share", "icons"),
		filepath.Join(execx.Home(), "Documents", "projects", "config", "home", "dots", "cursors", "themes"),
	}
	wantTheme, wantID := strings.ToLower(theme), strings.ToLower(id)
	for _, root := range roots {
		ents, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, e := range ents {
			base := e.Name()
			low := strings.ToLower(base)
			if low != wantTheme && low != wantID {
				continue
			}
			p := filepath.Join(root, base)
			if hasCursor(p) {
				return p, base
			}
		}
	}
	return "", theme
}

func nearestSize(path string, want int) int {
	data, err := os.ReadFile(path)
	if err != nil || len(data) < 16 || string(data[:4]) != "Xcur" {
		return want
	}
	ntoc := binary.LittleEndian.Uint32(data[12:])
	sizes := map[int]bool{}
	off := 16
	for i := uint32(0); i < ntoc && off+12 <= len(data); i++ {
		ctype := binary.LittleEndian.Uint32(data[off:])
		subtype := binary.LittleEndian.Uint32(data[off+4:])
		pos := binary.LittleEndian.Uint32(data[off+8:])
		off += 12
		if ctype != 0xFFFD0002 {
			continue
		}
		sz := int(subtype)
		if sz == 0 && int(pos)+12 <= len(data) {
			sz = int(binary.LittleEndian.Uint32(data[pos+8:]))
		}
		if sz > 0 {
			sizes[sz] = true
		}
	}
	if len(sizes) == 0 {
		return want
	}
	best, bestD := want, 1<<30
	for s := range sizes {
		d := s - want
		if d < 0 {
			d = -d
		}
		if d < bestD || (d == bestD && s < best) {
			best, bestD = s, d
		}
	}
	return best
}

func rewriteGTK(file, theme, size string) {
	st, err := os.Lstat(file)
	if err != nil {
		return
	}
	if st.Mode()&os.ModeSymlink != 0 {
		raw, err := os.ReadFile(file)
		if err != nil {
			return
		}
		_ = os.Remove(file)
		if os.WriteFile(file, raw, 0o644) != nil {
			return
		}
	}
	raw, err := os.ReadFile(file)
	if err != nil {
		return
	}
	lines := strings.Split(string(raw), "\n")
	var name, sz bool
	for i, line := range lines {
		if strings.HasPrefix(line, "gtk-cursor-theme-name=") {
			lines[i] = "gtk-cursor-theme-name=" + theme
			name = true
		}
		if strings.HasPrefix(line, "gtk-cursor-theme-size=") {
			lines[i] = "gtk-cursor-theme-size=" + size
			sz = true
		}
	}
	if !name {
		lines = append(lines, "gtk-cursor-theme-name="+theme)
	}
	if !sz {
		lines = append(lines, "gtk-cursor-theme-size="+size)
	}
	_ = os.WriteFile(file, []byte(strings.Join(lines, "\n")), 0o644)
}

func Set(id, size, theme string) int {
	if size == "" {
		if s := os.Getenv("AURORA_CURSOR_SIZE"); s != "" {
			size = s
		} else {
			size = "24"
		}
	}
	if theme == "" {
		theme = id
	}
	theme = resolveTheme(id, theme)
	dir := findTheme(theme)
	if dir == "" && theme != id {
		dir = findTheme(id)
	}
	if dir == "" {
		dir, theme = scanThemes(id, theme)
	}
	state := cacheDir()
	_ = os.MkdirAll(state, 0o755)
	_ = os.WriteFile(filepath.Join(state, "current-cursor"), []byte(id+"\n"), 0o644)
	_ = os.WriteFile(filepath.Join(state, "current-cursor-theme"), []byte(theme+"\n"), 0o644)
	_ = os.WriteFile(filepath.Join(state, "current-cursor-size"), []byte(size+"\n"), 0o644)
	if dir == "" {
		return 1
	}
	def := filepath.Join(execx.Home(), ".icons", "default")
	_ = os.MkdirAll(def, 0o755)
	idx := filepath.Join(def, "index.theme")
	if st, err := os.Lstat(idx); err == nil && st.Mode()&os.ModeSymlink != 0 {
		_ = os.Remove(idx)
	}
	_ = os.WriteFile(idx, []byte("[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits="+theme+"\n"), 0o644)
	rewriteGTK(filepath.Join(execx.Home(), ".config", "gtk-3.0", "settings.ini"), theme, size)
	rewriteGTK(filepath.Join(execx.Home(), ".config", "gtk-4.0", "settings.ini"), theme, size)
	_ = execx.RunOK(2*time.Second, "gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme)
	_ = execx.RunOK(2*time.Second, "gsettings", "set", "org.gnome.desktop.interface", "cursor-size", size)
	hyprSize := size
	if n, err := strconv.Atoi(size); err == nil {
		left := filepath.Join(dir, "cursors", "left_ptr")
		if _, err := os.Stat(left); err != nil {
			left = filepath.Join(dir, "cursors", "default")
		}
		hyprSize = strconv.Itoa(nearestSize(left, n))
	}
	_ = execx.RunOK(2*time.Second, "hyprctl", "eval", "hl.env('XCURSOR_THEME', '"+theme+"')")
	_ = execx.RunOK(2*time.Second, "hyprctl", "eval", "hl.env('XCURSOR_SIZE', '"+hyprSize+"')")
	_ = execx.RunOK(2*time.Second, "hyprctl", "eval", "hl.env('HYPRCURSOR_THEME', '"+theme+"')")
	_ = execx.RunOK(2*time.Second, "hyprctl", "eval", "hl.env('HYPRCURSOR_SIZE', '"+hyprSize+"')")
	_ = execx.RunOK(2*time.Second, "hyprctl", "eval", `hl.config({ cursor = { enable_hyprcursor = true, no_hardware_cursors = true, use_cpu_buffer = false, hide_on_key_press = false, default_monitor = 'DP-1' } })`)
	_ = execx.RunOK(2*time.Second, "hyprctl", "setcursor", theme, hyprSize)
	_ = execx.RunOK(2*time.Second, "hyprctl", "setcursor", theme, size)
	return 0
}

func Load() int {
	id, size := "macos", "24"
	if s := os.Getenv("AURORA_CURSOR_SIZE"); s != "" {
		size = s
	}
	if b, err := os.ReadFile(filepath.Join(cacheDir(), "current-cursor")); err == nil {
		if v := strings.TrimSpace(string(b)); v != "" {
			id = v
		}
	}
	if b, err := os.ReadFile(filepath.Join(cacheDir(), "current-cursor-size")); err == nil {
		if v := strings.TrimSpace(string(b)); v != "" {
			size = v
		}
	}
	return Set(id, size, "")
}

func Main(args []string) int {
	if len(args) == 0 || args[0] == "load" {
		return Load()
	}
	if args[0] == "set" {
		args = args[1:]
	}
	if len(args) == 0 {
		return 2
	}
	size, theme := "", ""
	if len(args) > 1 {
		size = args[1]
	}
	if len(args) > 2 {
		theme = args[2]
	}
	return Set(args[0], size, theme)
}
