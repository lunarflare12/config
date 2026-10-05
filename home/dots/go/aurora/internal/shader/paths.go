package shader

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"aurora/internal/execx"
)

var (
	home       = execx.Home()
	cacheDir   = filepath.Join(home, ".cache", "aurora")
	statusPath = filepath.Join(cacheDir, "shader-status.json")
	lockPath   = filepath.Join(cacheDir, "shader-build.lock")
	targetPath = filepath.Join(cacheDir, "shader-build.target")
	picsPath   = filepath.Join(cacheDir, "shader-pics.json")
	fossilizeB = filepath.Join(home, ".local", "share", "Steam", "ubuntu12_64", "fossilize_replay")
	steamRun   = "/run/current-system/sw/bin/steam-run"
	nvidiaICD  = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
	nvsettings = "/run/current-system/sw/bin/nvidia-settings"
)

var steamRoots = []string{
	filepath.Join(home, ".local", "share", "Steam"),
	"/steam",
}

var shaderRoots = []string{
	"/steam/steamapps/shadercache",
	filepath.Join(home, ".cache", "steam-shadercache"),
	filepath.Join(home, ".local", "share", "Steam", "steamapps", "shadercache"),
}

var skipName = regexp.MustCompile(`(?i)(proton|steam linux runtime|steamworks|redistributable|dedicated server|\bsdk\b|soundtrack|compatibility tool|steamworks common|proton experimental)`)

var hiddenAppIDs = map[string]struct{}{"570": {}}

const (
	stateUpdateRequired = 2
	stateUpdateRunning  = 256
	stateUpdatePaused   = 512
	stateUpdateStarted  = 1024
	stateDownloading    = 1 << 20
	stateStaging        = 1 << 21
	stateCommitting     = 1 << 22
	stateBusy           = stateUpdateRunning | stateUpdatePaused | stateUpdateStarted |
		stateDownloading | stateStaging | stateCommitting
)

var steamReplayRE = regexp.MustCompile(`Still replaying (\d+) \((\d+)%,\s*(\d+)/(\d+)\)`)

var shaderLogs = []string{
	filepath.Join(home, ".local", "share", "Steam", "logs", "shader_log.txt"),
	filepath.Join(home, ".steam", "steam", "logs", "shader_log.txt"),
}

var acfKV = regexp.MustCompile(`"([^"]+)"\s+"([^"]*)"`)
var pathRE = regexp.MustCompile(`"path"\s+"([^"]+)"`)
var appIDRE = regexp.MustCompile(`(?:SteamLaunch\s+)?AppId[=:](\d+)|compatdata/(\d+)`)
var shadercacheRE = regexp.MustCompile(`shadercache/(\d+)`)

func isTool(name, installdir string) bool {
	return skipName.MatchString(name + " " + installdir)
}

func isHidden(appid string) bool {
	_, ok := hiddenAppIDs[appid]
	return ok
}

func acfValues(text string) map[string]string {
	out := map[string]string{}
	for _, m := range acfKV.FindAllStringSubmatch(text, -1) {
		if _, ok := out[m[1]]; !ok {
			out[m[1]] = m[2]
		}
	}
	return out
}

func librarySteamapps() []string {
	var found []string
	seen := map[string]struct{}{}

	add := func(steamapps string) {
		key := steamapps
		if abs, err := filepath.Abs(steamapps); err == nil {
			if resolved, err := filepath.EvalSymlinks(abs); err == nil {
				key = resolved
			} else {
				key = abs
			}
		}
		if _, ok := seen[key]; ok {
			return
		}
		st, err := os.Stat(steamapps)
		if err != nil || !st.IsDir() {
			return
		}
		seen[key] = struct{}{}
		found = append(found, steamapps)
	}

	for _, root := range steamRoots {
		add(filepath.Join(root, "steamapps"))
		folders := filepath.Join(root, "steamapps", "libraryfolders.vdf")
		b, err := os.ReadFile(folders)
		if err != nil {
			continue
		}
		for _, m := range pathRE.FindAllStringSubmatch(string(b), -1) {
			add(filepath.Join(m[1], "steamapps"))
		}
	}
	return found
}

func iterManifests() []string {
	var out []string
	seen := map[string]struct{}{}
	for _, steamapps := range librarySteamapps() {
		matches, _ := filepath.Glob(filepath.Join(steamapps, "appmanifest_*.acf"))
		for _, man := range matches {
			base := filepath.Base(man)
			appid := strings.TrimPrefix(strings.TrimSuffix(base, ".acf"), "appmanifest_")
			if _, ok := seen[appid]; ok {
				continue
			}
			seen[appid] = struct{}{}
			out = append(out, man)
		}
	}
	return out
}

func gameKind(appid, steamapps, installdir string) string {
	if st, err := os.Stat(filepath.Join(steamapps, "compatdata", appid)); err == nil && st.IsDir() {
		return "proton"
	}
	common := filepath.Join(steamapps, "common", installdir)
	for _, rel := range []string{
		"game/bin/linuxsteamrt64",
		"bin/linuxsteamrt64",
		"bin/linux64",
		"bin/linux32",
	} {
		if _, err := os.Stat(filepath.Join(common, rel)); err == nil {
			return "native"
		}
	}
	return "native"
}

func shaderDir(appid string) string {
	for _, root := range shaderRoots {
		p := filepath.Join(root, appid)
		if st, err := os.Stat(p); err == nil && st.IsDir() {
			return p
		}
	}
	return ""
}

func dirSize(path string) int64 {
	if path == "" {
		return 0
	}
	var total int64
	_ = filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		total += info.Size()
		return nil
	})
	return total
}

func newestMtime(path string) int64 {
	if path == "" {
		return 0
	}
	var newest int64
	_ = filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		mt := info.ModTime().Unix()
		if mt > newest {
			newest = mt
		}
		return nil
	})
	return newest
}

func fmtBytes(n int64) string {
	switch {
	case n >= 1073741824:
		return strings.TrimSpace(fmt.Sprintf(" %.1f ГиБ", float64(n)/1073741824))
	case n >= 1048576:
		return strings.TrimSpace(fmt.Sprintf(" %.1f МиБ", float64(n)/1048576))
	case n >= 1024:
		return strings.TrimSpace(fmt.Sprintf(" %.0f КиБ", float64(n)/1024))
	default:
		return strconv.FormatInt(n, 10) + " Б"
	}
}

func fileExists(path string) bool {
	st, err := os.Stat(path)
	return err == nil && !st.IsDir()
}
