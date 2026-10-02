package spotify

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var keys = []string{
	"text", "subtext", "sidebar-text", "main", "main-elevated", "highlight",
	"highlight-elevated", "sidebar", "player", "card", "shadow", "selected-row",
	"button", "button-active", "button-disabled", "tab-active", "notification",
	"notification-error", "misc",
}

func Main(args []string) int {
	if len(args) > 0 && args[0] == "theme" {
		args = args[1:]
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/dd"
	}
	if err := applyTheme(home); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	return 0
}

func applyTheme(home string) error {
	aurora := filepath.Join(home, ".config", "aurora")
	out := filepath.Join(home, ".cache", "aurora", "spotify-xpui")
	colors, err := loadColors(aurora)
	if err != nil {
		return err
	}
	values := palette(colors)
	// Always dark chrome — palette follows aurora accents, not light/dark flip.
	if err := os.MkdirAll(out, 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(out, "colors.css"), []byte(writeCSS(values)), 0o644); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(out, "aurora.js"), []byte(writeJS(values, false)), 0o644); err != nil {
		return err
	}
	if xpui := findXPUI(); xpui != "" {
		writeIndex(xpui, out)
	}
	return nil
}

func hexOf(value, fallback string) string {
	raw := strings.TrimSpace(strings.TrimPrefix(value, "#"))
	if len(raw) == 3 {
		var b strings.Builder
		for _, ch := range raw {
			b.WriteRune(ch)
			b.WriteRune(ch)
		}
		raw = b.String()
	}
	if len(raw) != 6 {
		raw = strings.TrimPrefix(fallback, "#")
	}
	return strings.ToLower(raw)
}

func loadColors(aurora string) (map[string]string, error) {
	themeID := "macos-golden-gate"
	active := filepath.Join(aurora, "active-theme")
	if b, err := os.ReadFile(active); err == nil {
		if s := strings.TrimSpace(string(b)); s != "" {
			themeID = s
		}
	}
	path := filepath.Join(aurora, "themes", themeID+".json")
	b, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]string{}, nil
		}
		return nil, err
	}
	var root map[string]any
	if err := json.Unmarshal(b, &root); err != nil {
		return map[string]string{}, nil
	}
	raw, _ := root["colors"].(map[string]any)
	out := make(map[string]string, len(raw))
	for k, v := range raw {
		out[k] = fmt.Sprint(v)
	}
	return out, nil
}

func pick(colors map[string]string, key, fb string) string {
	if v, ok := colors[key]; ok && v != "" {
		return hexOf(v, fb)
	}
	return hexOf("", fb)
}

func palette(colors map[string]string) map[string]string {
	background := pick(colors, "background", "1c1c1e")
	surface := pick(colors, "surface", "2c2c2e")
	text := pick(colors, "text", "f5f5f7")
	accent := pick(colors, "accent", "0a84ff")
	sub := pick(colors, "textSecondary", "98989d")
	if v, ok := colors["textMuted"]; ok && v != "" {
		sub = hexOf(v, sub)
	}
	return map[string]string{
		"text":               text,
		"subtext":            sub,
		"sidebar-text":       text,
		"main":               background,
		"main-elevated":      surface,
		"highlight":          pick(colors, "surfaceHover", "3a3a3c"),
		"highlight-elevated": pick(colors, "surfaceActive", "48484a"),
		"sidebar":            pick(colors, "backgroundDark", background),
		"player":             pick(colors, "backgroundDark", background),
		"card":               surface,
		"shadow":             pick(colors, "backgroundDark", "000000"),
		"selected-row":       pick(colors, "surfaceHover", "3a3a3c"),
		"button":             accent,
		"button-active":      pick(colors, "accentHover", accent),
		"button-disabled":    pick(colors, "surfaceActive", "48484a"),
		"tab-active":         accent,
		"notification":       pick(colors, "info", accent),
		"notification-error": pick(colors, "error", "ff453a"),
		"misc":               pick(colors, "separator", "38383a"),
	}
}

func writeCSS(values map[string]string) string {
	var b strings.Builder
	b.WriteString(":root {\n")
	for _, key := range keys {
		hx := values[key]
		fmt.Fprintf(&b, "    --spice-%s: #%s;\n", key, hx)
	}
	b.WriteString("\n")
	for _, key := range keys {
		hx := values[key]
		fmt.Fprintf(&b, "    --spice-rgb-%s: %s;\n", key, rgbOf(hx))
	}
	b.WriteString("}\n\n")
	return b.String()
}

func rgbOf(hx string) string {
	if len(hx) < 6 {
		return "0,0,0"
	}
	var r, g, b int
	fmt.Sscanf(hx[0:2], "%x", &r)
	fmt.Sscanf(hx[2:4], "%x", &g)
	fmt.Sscanf(hx[4:6], "%x", &b)
	return fmt.Sprintf("%d,%d,%d", r, g, b)
}

func writeJS(values map[string]string, light bool) string {
	payload := make(map[string]string, len(keys))
	for _, key := range keys {
		payload[key] = "#" + values[key]
	}
	js, _ := json.Marshal(payload)
	lightS := "false"
	if light {
		lightS = "true"
	}
	return fmt.Sprintf(`(function () {
  const light = %s;
  const palette = %s;
  const html = document.documentElement;
  function paint() {
    html.classList.toggle('encore-light-theme', light);
    html.classList.toggle('encore-dark-theme', !light);
    html.style.colorScheme = light ? 'light' : 'dark';
    Object.keys(palette).forEach(function (name) {
      const hex = String(palette[name] || '').replace('#', '');
      if (hex.length !== 6) return;
      const r = parseInt(hex.slice(0, 2), 16);
      const g = parseInt(hex.slice(2, 4), 16);
      const b = parseInt(hex.slice(4, 6), 16);
      html.style.setProperty('--spice-' + name, '#' + hex);
      html.style.setProperty('--spice-rgb-' + name, r + ',' + g + ',' + b);
    });
  }
  paint();
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', paint);
})();
`, lightS, string(js))
}

func findXPUI() string {
	if env := os.Getenv("SPOTIFY_BIN"); env != "" {
		if xpui := xpuiFromBin(env); xpui != "" {
			return xpui
		}
	}
	matches, _ := filepath.Glob("/nix/store/*-spicetify-Dribbblish/bin/spotify")
	for _, bin := range matches {
		if xpui := xpuiFromBin(bin); xpui != "" {
			return xpui
		}
	}
	return ""
}

func xpuiFromBin(bin string) string {
	real, err := filepath.EvalSymlinks(bin)
	if err != nil {
		real = bin
	}
	dir := filepath.Dir(real)
	for _, xpui := range []string{
		filepath.Join(dir, "Apps", "xpui"),
		filepath.Join(dir, "..", "share", "spotify", "Apps", "xpui"),
	} {
		if st, err := os.Stat(filepath.Join(xpui, "colors.css")); err == nil && !st.IsDir() {
			return xpui
		}
	}
	return ""
}

func writeIndex(xpui, out string) {
	source := filepath.Join(xpui, "index.html")
	b, err := os.ReadFile(source)
	if err != nil {
		return
	}
	html := string(b)
	tag := "<script defer src='extensions/aurora.js'></script>"
	if !strings.Contains(html, "extensions/aurora.js") {
		html = strings.Replace(html, "</body>", tag+"</body>", 1)
		if !strings.Contains(html, "extensions/aurora.js") {
			html += tag + "\n"
		}
	}
	_ = os.WriteFile(filepath.Join(out, "index.html"), []byte(html), 0o644)
}
