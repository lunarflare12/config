package shader

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

func procComm(pid int) string {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "comm"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func procPPid(pid int) int {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "status"))
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "PPid:") {
			n, err := strconv.Atoi(strings.TrimSpace(strings.TrimPrefix(line, "PPid:")))
			if err != nil {
				return 0
			}
			return n
		}
	}
	return 0
}

func procCmdline(pid int) string {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return ""
	}
	return strings.ReplaceAll(string(b), "\x00", " ")
}

func fossilizeAppIDs() map[string]struct{} {
	ids := map[string]struct{}{}
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return ids
	}
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		if !strings.HasPrefix(procComm(pid), "fossilize") {
			continue
		}
		cmd := procCmdline(pid)
		if m := shadercacheRE.FindStringSubmatch(cmd); m != nil {
			ids[m[1]] = struct{}{}
		}
	}
	return ids
}

func steamOwnedFossilize(pid int) bool {
	cur := pid
	for i := 0; i < 16; i++ {
		cur = procPPid(cur)
		if cur <= 1 {
			return false
		}
		if procComm(cur) == "steam" {
			return true
		}
	}
	return false
}

type steamProg struct {
	Percent float64
	Done    int
	Total   int
}

func steamShaderProgress() map[string]steamProg {
	found := map[string]steamProg{}
	for _, path := range shaderLogs {
		b, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		if len(b) > 65536 {
			b = b[len(b)-65536:]
		}
		tail := string(b)
		for _, m := range steamReplayRE.FindAllStringSubmatch(tail, -1) {
			pct, _ := strconv.ParseFloat(m[2], 64)
			done, _ := strconv.Atoi(m[3])
			total, _ := strconv.Atoi(m[4])
			found[m[1]] = steamProg{Percent: pct, Done: done, Total: total}
		}
	}
	return found
}

func runningAppIDs(psText string) map[string]struct{} {
	ids := map[string]struct{}{}
	for _, line := range strings.Split(psText, "\n") {
		if strings.Contains(line, "steam://rungameid/") &&
			!strings.Contains(line, "AppId=") &&
			!strings.Contains(line, "compatdata/") {
			continue
		}
		for _, m := range appIDRE.FindAllStringSubmatch(line, -1) {
			for _, g := range m[1:] {
				if g != "" {
					ids[g] = struct{}{}
				}
			}
		}
	}
	return ids
}

func psArgs() string {
	_, out := execx.Run(5*time.Second, "ps", "-eo", "args")
	return out
}

func notify(title, body string) {
	_, _ = execx.Run(5*time.Second, "notify-send", "-a", "Shaders", title, body)
}

func replayFiles(foz string) []string {
	if foz == "" {
		return nil
	}
	matches, _ := filepath.Glob(filepath.Join(filepath.Dir(foz), "replay_cache*.foz"))
	return matches
}

func replayStats(foz string) (total int64, newest int64) {
	for _, p := range replayFiles(foz) {
		st, err := os.Stat(p)
		if err != nil {
			continue
		}
		total += st.Size()
		mt := st.ModTime().Unix()
		if mt > newest {
			newest = mt
		}
	}
	return total, newest
}

func replayComplete(foz, replay string) bool {
	if foz == "" {
		return false
	}
	st, err := os.Stat(foz)
	if err != nil {
		return false
	}
	fozSz := st.Size()
	fozMtime := st.ModTime().Unix()
	repSz, repMtime := replayStats(foz)
	if replay != "" && repSz == 0 {
		rst, err := os.Stat(replay)
		if err != nil {
			return false
		}
		repSz = rst.Size()
		repMtime = rst.ModTime().Unix()
	}
	if fozSz >= 256*1024*1024 {
		min := int64(32 * 1024 * 1024)
		if fozSz/50 > min {
			min = fozSz / 50
		}
		return repSz >= min
	}
	if fozSz >= 16*1024*1024 {
		min := int64(256 * 1024)
		if fozSz/20 > min {
			min = fozSz / 20
		}
		return repMtime+60 >= fozMtime && repSz >= min
	}
	return true
}

func mergedNvidiaBytes(nvidia string) int64 {
	if nvidia == "" {
		return 0
	}
	st, err := os.Stat(nvidia)
	if err != nil || !st.IsDir() {
		return 0
	}
	var total int64
	_ = filepath.Walk(nvidia, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if filepath.Base(p) == "steamapp_merged_shader_cache.bin" {
			total += info.Size()
		}
		return nil
	})
	return total
}

type fozInfo struct {
	path  string
	mtime int64
	size  int64
}

func fozCandidates(shader string) []string {
	fozRoot := filepath.Join(shader, "fozpipelinesv6")
	st, err := os.Stat(fozRoot)
	if err != nil || !st.IsDir() {
		return nil
	}
	var found []fozInfo
	_ = filepath.Walk(fozRoot, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if filepath.Base(p) == "steam_pipeline_cache.foz" {
			found = append(found, fozInfo{path: p, mtime: info.ModTime().Unix(), size: info.Size()})
		}
		return nil
	})
	// sort by mtime, size descending
	for i := 0; i < len(found); i++ {
		for j := i + 1; j < len(found); j++ {
			if found[j].mtime > found[i].mtime ||
				(found[j].mtime == found[i].mtime && found[j].size > found[i].size) {
				found[i], found[j] = found[j], found[i]
			}
		}
	}
	var big []string
	for _, f := range found {
		if f.size >= 16*1024*1024 {
			big = append(big, f.path)
		}
	}
	if len(big) > 0 {
		return []string{big[0]}
	}
	if len(found) > 0 {
		return []string{found[0].path}
	}
	return nil
}

func fozBundle(shader string) (foz, replay, whitelist string) {
	found := fozCandidates(shader)
	if len(found) == 0 {
		return "", "", ""
	}
	foz = found[0]
	wl := filepath.Join(filepath.Dir(foz), "steam_pipeline_cache_whitelist.foz")
	if fileExists(wl) {
		whitelist = wl
	}
	replays, _ := filepath.Glob(filepath.Join(filepath.Dir(foz), "replay_cache*.foz"))
	var best string
	var bestMT int64
	for _, r := range replays {
		st, err := os.Stat(r)
		if err != nil {
			continue
		}
		mt := st.ModTime().Unix()
		if best == "" || mt > bestMT {
			best = r
			bestMT = mt
		}
	}
	replay = best
	return foz, replay, whitelist
}
