package steamlock

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"aurora/internal/execx"
)

func steamBin(home string) string {
	if p := execx.Look("steam"); p != "" {
		return p
	}
	return filepath.Join(home, ".nix-profile/bin/steam")
}

// Закрепить Proton LaunchOptions. Кэши шейдеров не трогаем.

func appBlockSpan(text, appid string) (bodyAt, bodyEnd int, indent string, ok bool) {
	re := regexp.MustCompile(`(?m)^("` + regexp.QuoteMeta(appid) + `"\s*\n)(\t+)\{`)
	m := re.FindStringSubmatchIndex(text)
	if m == nil {
		return 0, 0, "", false
	}
	indent = text[m[4]:m[5]]
	brace := m[1] - 1
	depth := 0
	for i := brace; i < len(text); i++ {
		switch text[i] {
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return brace + 1, i, indent, true
			}
		}
	}
	return 0, 0, "", false
}

func patchLaunchOptions(text, appid, cmd string) string {
	bodyAt, bodyEnd, indent, ok := appBlockSpan(text, appid)
	if !ok {
		return text
	}
	body := text[bodyAt:bodyEnd]
	loRe := regexp.MustCompile(`"LaunchOptions"\s*"[^"]*"`)
	if loRe.MatchString(body) {
		body = loRe.ReplaceAllString(body, `"LaunchOptions"		"`+cmd+`"`)
	} else {
		line := indent + "\t\"LaunchOptions\"\t\t\"" + cmd + "\"\n"
		body = "\n" + line + strings.TrimLeft(body, "\n")
	}
	return text[:bodyAt] + body + text[bodyEnd:]
}

func stripLaunchOptions(text, appid string) string {
	bodyAt, bodyEnd, _, ok := appBlockSpan(text, appid)
	if !ok {
		return text
	}
	body := text[bodyAt:bodyEnd]
	re := regexp.MustCompile(`\n?\t+"LaunchOptions"\s*"[^"]*"\n?`)
	body2 := re.ReplaceAllString(body, "\n")
	if body2 == body {
		return text
	}
	return text[:bodyAt] + body2 + text[bodyEnd:]
}

func patchDesktops(home string) {
	apps := filepath.Join(home, ".local", "share", "applications")
	steamLaunch := steamBin(home)
	ents, err := os.ReadDir(apps)
	if err != nil {
		return
	}
	appidRe := regexp.MustCompile(`steam://rungameid/(\d+)`)
	execRe := regexp.MustCompile(`(?m)^Exec=.*$`)
	wmRe := regexp.MustCompile(`(?m)^StartupWMClass=.*$`)
	for _, e := range ents {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".desktop") {
			continue
		}
		path := filepath.Join(apps, e.Name())
		b, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		text := string(b)
		m := appidRe.FindStringSubmatch(text)
		if m == nil {
			continue
		}
		appid := m[1]
		want := "Exec=" + steamLaunch + " steam://rungameid/" + appid
		newText := execRe.ReplaceAllString(text, want)
		wm := "StartupWMClass=steam_app_" + appid
		if wmRe.MatchString(newText) {
			newText = wmRe.ReplaceAllString(newText, wm)
		} else {
			if !strings.HasSuffix(newText, "\n") {
				newText += "\n"
			}
			newText += wm + "\n"
		}
		if newText != text {
			_ = os.WriteFile(path, []byte(newText), 0o644)
		}
	}
}

func Main(args []string) int {
	home := execx.Home()
	aurora := execx.Look("aurora")
	if aurora == "" {
		aurora = filepath.Join(home, ".local/bin/aurora")
	}
	wanted := map[string]string{
		"761890": aurora + " game albion %command%",
	}
	userdata := filepath.Join(home, ".local", "share", "Steam", "userdata")
	_ = filepath.WalkDir(userdata, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if d.Name() != "localconfig.vdf" {
			return nil
		}
		if filepath.Base(filepath.Dir(path)) != "config" {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		text := string(b)
		orig := text
		for appid, cmd := range wanted {
			text = patchLaunchOptions(text, appid, cmd)
		}
		text = stripLaunchOptions(text, "2357570")
		if text != orig {
			_ = os.WriteFile(path, []byte(text), 0o644)
		}
		return nil
	})
	patchDesktops(home)
	return 0
}
