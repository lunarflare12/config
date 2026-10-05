package shader

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

func busyGame(appid string) string {
	live := runningAppIDs(psArgs())
	if len(live) == 0 {
		return ""
	}
	if appid != "" {
		if _, ok := live[appid]; !ok {
			return ""
		}
	}
	for _, man := range iterManifests() {
		base := filepath.Base(man)
		mid := strings.TrimPrefix(strings.TrimSuffix(base, ".acf"), "appmanifest_")
		if _, ok := live[mid]; !ok {
			continue
		}
		if appid != "" && mid != appid {
			continue
		}
		b, err := os.ReadFile(man)
		if err != nil {
			continue
		}
		vals := acfValues(string(b))
		name := vals["name"]
		if name == "" {
			name = mid
		}
		if isHidden(mid) || isTool(name, vals["installdir"]) {
			continue
		}
		return name
	}
	return ""
}

func nvidiaCompileEnv(shader string) map[string]string {
	nvCache := filepath.Join(shader, "nvidiav1")
	env := map[string]string{
		"__GL_SHADER_DISK_CACHE":              "1",
		"__GL_SHADER_DISK_CACHE_SKIP_CLEANUP": "1",
		"__GL_SHADER_DISK_CACHE_SIZE":         "34359738368",
		"__GL_SHADER_DISK_CACHE_PATH":         nvCache,
		"DISABLE_LAYER_MESA_DEVICE_SELECT":    "1",
	}
	if fileExists(nvidiaICD) {
		env["VK_DRIVER_FILES"] = nvidiaICD
		env["VK_ICD_FILENAMES"] = nvidiaICD
	}
	return env
}

func runFossilize(shader, foz, replayPrefix, whitelist string) int {
	if !fileExists(fossilizeB) {
		return 1
	}
	cpu := runtimeNumCPU()
	threads := max(2, min(4, cpu/4))
	var runner []string
	if fileExists(steamRun) {
		runner = []string{steamRun}
	}
	pin := nvidiaCompileEnv(shader)
	if fileExists(nvsettings) {
		cmd := exec.Command(nvsettings, "-a", "[gpu:0]/GPUPowerMizerMode=1")
		cmd.Stdout = nil
		cmd.Stderr = nil
		_ = cmd.Run()
	}
	inner := []string{"env"}
	for k, v := range pin {
		inner = append(inner, k+"="+v)
	}
	inner = append(inner,
		fossilizeB,
		"--num-threads", strconv.Itoa(threads),
		"--device-index", "0",
		"--shader-cache-size", "8192",
		"--progress",
		"--disable-rate-limiter",
		"--replayer-cache", replayPrefix,
	)
	if whitelist != "" {
		inner = append(inner, "--on-disk-validation-whitelist", whitelist)
	}
	inner = append(inner, foz)
	cmdArgs := append(runner, inner...)

	env := os.Environ()
	for k, v := range pin {
		env = append(env, k+"="+v)
	}
	_ = os.MkdirAll(cacheDir, 0o755)
	logPath := filepath.Join(cacheDir, "shader-build.log")
	fh, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return 1
	}
	defer fh.Close()
	_, _ = fh.WriteString(fmt.Sprintf("\n# %s %s\n", time.Now().Format("2006-01-02 15:04:05"), strings.Join(cmdArgs, " ")))
	_ = fh.Sync()
	cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
	cmd.Env = env
	cmd.Stdout = fh
	cmd.Stderr = fh
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func runtimeNumCPU() int {
	b, err := os.ReadFile("/sys/devices/system/cpu/online")
	if err != nil {
		return 8
	}
	s := strings.TrimSpace(string(b))
	if i := strings.LastIndex(s, "-"); i >= 0 {
		n, err := strconv.Atoi(s[i+1:])
		if err == nil {
			return n + 1
		}
	}
	return 8
}

func replayPIDs() []int {
	var pids []int
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		if strings.HasPrefix(procComm(pid), "fossilize") {
			pids = append(pids, pid)
		}
	}
	return pids
}

func killReplay() {
	for _, pid := range replayPIDs() {
		if steamOwnedFossilize(pid) {
			continue
		}
		_ = syscall.Kill(pid, syscall.SIGTERM)
	}
	time.Sleep(1 * time.Second)
	for _, pid := range replayPIDs() {
		if steamOwnedFossilize(pid) {
			continue
		}
		_ = syscall.Kill(pid, syscall.SIGKILL)
	}
}

func stopJobs() {
	if pid := lockPID(); pid != 0 {
		_ = syscall.Kill(pid, syscall.SIGTERM)
	}
	_ = os.Remove(lockPath)
	_ = os.Remove(targetPath)
	killReplay()
	time.Sleep(300 * time.Millisecond)
	killReplay()
}

func spawnDaemon(appid string) error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	_ = os.MkdirAll(cacheDir, 0o755)
	logPath := filepath.Join(cacheDir, "shader-ctl.out")
	log, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	args := []string{"shader", "build"}
	if base := filepath.Base(exe); base == "shader-ctl" || base == "aurora-shader" {
		args = []string{"build"}
	}
	if appid != "" {
		args = append(args, appid)
	}
	cmd := exec.Command(exe, args...)
	cmd.Env = append(os.Environ(), "SHADER_CTL_DAEMON=1")
	cmd.Stdout = log
	cmd.Stderr = log
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		_ = log.Close()
		return err
	}
	// Detach: don't wait; close our handle after start.
	go func() { _ = log.Close() }()
	return nil
}

func cmdBuild(appid string) int {
	steamFoss := fossilizeAppIDs()
	if len(steamFoss) > 0 {
		payload := collect()
		writeStatus(payload)
		var names []string
		for _, g := range payload.Games {
			if _, ok := steamFoss[g.ID]; ok {
				names = append(names, g.Name)
			}
		}
		if len(names) == 0 {
			names = []string{"игру"}
		}
		notify("Шейдеры", "Steam уже собирает: "+strings.Join(names, ", "))
		printStatus(payload)
		return 0
	}

	existing := lockPID()
	if existing != 0 {
		curID, curName := readTarget()
		same := appid != "" && appid == curID
		if same || appid == "" {
			payload := collect()
			writeStatus(payload)
			printStatus(payload)
			return 0
		}
		if os.Getenv("SHADER_CTL_DAEMON") == "1" {
			payload := collect()
			writeStatus(payload)
			printStatus(payload)
			return 0
		}
		payload := collect()
		newName := appid
		for _, g := range payload.Games {
			if g.ID == appid {
				newName = g.Name
				break
			}
		}
		notify("Шейдеры", fmt.Sprintf("Останавливаю %s, собираю %s", or(curName, curID), newName))
		stopJobs()
	}

	if os.Getenv("SHADER_CTL_DAEMON") != "1" {
		_ = spawnDaemon(appid)
		time.Sleep(300 * time.Millisecond)
		payload := collect()
		writeStatus(payload)
		printStatus(payload)
		return 0
	}

	_ = os.MkdirAll(cacheDir, 0o755)
	_ = os.WriteFile(lockPath, []byte(strconv.Itoa(os.Getpid())), 0o644)
	defer func() {
		b, err := os.ReadFile(lockPath)
		if err == nil {
			first := strings.TrimSpace(strings.Split(string(b), "\n")[0])
			if first == strconv.Itoa(os.Getpid()) {
				_ = os.Remove(lockPath)
			}
		}
		_ = os.Remove(targetPath)
		writeStatus(collect())
	}()

	payload := collect()
	writeStatus(payload)

	var targets []Game
	if appid != "" {
		for _, g := range payload.Games {
			if g.ID == appid && g.FozBytes != 0 {
				targets = append(targets, g)
			}
		}
	} else {
		for _, g := range payload.Games {
			if g.CanBuild && (g.Shaders == "stale" || g.Shaders == "missing" || g.Shaders == "building") {
				targets = append(targets, g)
			}
		}
	}

	var skipped, kept []Game
	var skippedNames []string
	for _, game := range targets {
		if busy := busyGame(game.ID); busy != "" {
			skipped = append(skipped, game)
			skippedNames = append(skippedNames, game.Name)
		} else {
			kept = append(kept, game)
		}
	}
	targets = kept
	if len(targets) == 0 {
		if len(skipped) > 0 {
			notify("Шейдеры", "Сейчас запущена "+strings.Join(skippedNames, ", ")+" — сборка после выхода")
			payload = collect()
			payload.Error = "running:" + strings.Join(skippedNames, ",")
		} else {
			notify("Шейдеры", "Собирать нечего — кэш актуален или нет FOZ")
			payload = collect()
		}
		writeStatus(payload)
		printStatus(payload)
		if len(skipped) > 0 {
			return 2
		}
		return 0
	}

	var failed []string
	for _, game := range targets {
		shader := shaderDir(game.ID)
		if shader == "" {
			failed = append(failed, game.Name)
			continue
		}
		type bundle struct {
			foz, replayPrefix, whitelist string
			sz                           int64
		}
		var bundles []bundle
		for _, foz := range fozCandidates(shader) {
			st, err := os.Stat(foz)
			if err != nil {
				continue
			}
			sz := st.Size()
			if sz < 16*1024*1024 {
				continue
			}
			wl := filepath.Join(filepath.Dir(foz), "steam_pipeline_cache_whitelist.foz")
			whitelist := ""
			if fileExists(wl) {
				whitelist = wl
			}
			bundles = append(bundles, bundle{
				foz: foz, replayPrefix: filepath.Join(filepath.Dir(foz), "replay_cache"),
				whitelist: whitelist, sz: sz,
			})
		}
		if len(bundles) == 0 {
			foz, replay, whitelist := fozBundle(shader)
			if foz != "" {
				parent := filepath.Dir(foz)
				if replay != "" {
					parent = filepath.Dir(replay)
				}
				bundles = append(bundles, bundle{
					foz: foz, replayPrefix: filepath.Join(parent, "replay_cache"),
					whitelist: whitelist, sz: 0,
				})
			}
		}
		if len(bundles) == 0 {
			failed = append(failed, game.Name)
			continue
		}
		writeTarget(game.ID, game.Name)
		writeStatus(collect())
		notify("Шейдеры", "Собираю "+game.Name+" без запуска")
		rc := 0
		for _, b := range bundles {
			rc = runFossilize(shader, b.foz, b.replayPrefix, b.whitelist)
			if rc != 0 {
				break
			}
		}
		if rc != 0 {
			failed = append(failed, game.Name)
		}
	}
	payload = collect()
	writeStatus(payload)
	if len(failed) > 0 {
		notify("Шейдеры", "Не собралось: "+strings.Join(failed, ", "))
		return 1
	}
	notify("Шейдеры", "Готово — можно заходить")
	printStatus(payload)
	return 0
}

func cmdStop() int {
	stopJobs()
	payload := collect()
	writeStatus(payload)
	printStatus(payload)
	return 0
}

func or(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
