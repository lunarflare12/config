package shader

import (
	"bytes"
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type Game struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Kind            string  `json:"kind"`
	Installed       bool    `json:"installed"`
	Updated         bool    `json:"updated"`
	Updating        bool    `json:"updating"`
	Running         bool    `json:"running"`
	BuildID         string  `json:"buildid"`
	GameLatest      string  `json:"gameLatest"`
	GameCurrent     *bool   `json:"gameCurrent"`
	ShadersOk       bool    `json:"shadersOk"`
	CheckedAt       int64   `json:"checkedAt"`
	LastUpdated     int64   `json:"lastUpdated"`
	Shaders         string  `json:"shaders"`
	InstallBytes    int64   `json:"installBytes"`
	CacheBytes      int64   `json:"cacheBytes"`
	NvidiaBytes     int64   `json:"nvidiaBytes"`
	FozBytes        int64   `json:"fozBytes"`
	FozNewer        bool    `json:"fozNewer"`
	DownloadBytes   int64   `json:"downloadBytes"`
	DownloadTotal   int64   `json:"downloadTotal"`
	DownloadPercent float64 `json:"downloadPercent"`
	BuildPercent    float64 `json:"buildPercent"`
	Detail          string  `json:"detail"`
	Action          string  `json:"action"`
	CanBuild        bool    `json:"canBuild"`
}

type Status struct {
	TS              int64    `json:"ts"`
	Building        bool     `json:"building"`
	BuildingPid     int      `json:"buildingPid"`
	BuildingName    string   `json:"buildingName"`
	CheckedAt       int64    `json:"checkedAt"`
	Stale           bool     `json:"stale"`
	Updating        bool     `json:"updating"`
	UpdatingName    string   `json:"updatingName"`
	DownloadPercent float64  `json:"downloadPercent"`
	BarKind         string   `json:"barKind"`
	BarName         string   `json:"barName"`
	BarPercent      float64  `json:"barPercent"`
	Games           []Game   `json:"games"`
	Error           string    `json:"error,omitempty"`
	CheckFailed     *[]string `json:"checkFailed,omitempty"`
}

type picsData struct {
	TS   int64                    `json:"ts"`
	Apps map[string]picsAppRemote `json:"apps"`
}

type picsAppRemote struct {
	BuildID     string `json:"buildid"`
	TimeUpdated int64  `json:"timeupdated"`
	FetchedAt   int64  `json:"fetchedAt"`
}

var (
	compileGfxRE     = regexp.MustCompile(`Compile graphics\s+(\d+)\s*/\s+(\d+)`)
	compileComputeRE = regexp.MustCompile(`Compile compute\s+(\d+)\s*/\s+(\d+)`)
	overallRE        = regexp.MustCompile(`Overall\s+(\d+)\s*/\s+(\d+)`)
)

func progressSnapshot() (compiled, fozDone, fozTotal int) {
	log := filepath.Join(cacheDir, "shader-build.log")
	b, err := os.ReadFile(log)
	if err != nil {
		return 0, 0, 0
	}
	if len(b) > 16384 {
		b = b[len(b)-16384:]
	}
	tail := string(b)
	if gfx := compileGfxRE.FindAllStringSubmatch(tail, -1); len(gfx) > 0 {
		compiled, _ = strconv.Atoi(gfx[len(gfx)-1][1])
	} else if compute := compileComputeRE.FindAllStringSubmatch(tail, -1); len(compute) > 0 {
		compiled, _ = strconv.Atoi(compute[len(compute)-1][1])
	}
	ov := overallRE.FindAllStringSubmatch(tail, -1)
	if len(ov) == 0 {
		return compiled, 0, 0
	}
	last := ov[len(ov)-1]
	fozDone, _ = strconv.Atoi(last[1])
	fozTotal, _ = strconv.Atoi(last[2])
	return compiled, fozDone, fozTotal
}

func lastProgress() string {
	compiled, done, total := progressSnapshot()
	if compiled != 0 && total != 0 {
		return strconv.Itoa(compiled) + " пайпл. · обход " + strconv.FormatFloat(100*float64(done)/float64(total), 'f', 0, 64) + "%"
	}
	if compiled != 0 {
		return strconv.Itoa(compiled) + " пайпл."
	}
	if total != 0 {
		return "обход " + strconv.FormatFloat(100*float64(done)/float64(total), 'f', 0, 64) + "% (" +
			strconv.Itoa(done) + "/" + strconv.Itoa(total) + ")"
	}
	return ""
}

func progressPercent() float64 {
	_, done, total := progressSnapshot()
	if total <= 0 {
		return 0
	}
	p := 100.0 * float64(done) / float64(total)
	if p > 99 {
		return 99
	}
	return p
}

func writeTarget(appid, name string) {
	_ = os.MkdirAll(cacheDir, 0o755)
	_ = os.WriteFile(targetPath, []byte(appid+"\n"+name+"\n"), 0o644)
}

func readTarget() (string, string) {
	b, err := os.ReadFile(targetPath)
	if err != nil {
		return "", ""
	}
	lines := strings.Split(string(b), "\n")
	id, name := "", ""
	if len(lines) > 0 {
		id = strings.TrimSpace(lines[0])
	}
	if len(lines) > 1 {
		name = strings.TrimSpace(lines[1])
	}
	return id, name
}

func lockPID() int {
	b, err := os.ReadFile(lockPath)
	if err != nil {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil || pid <= 0 {
		return 0
	}
	if err := syscall.Kill(pid, 0); err != nil {
		return 0
	}
	return pid
}

func encodeJSON(v any, indent bool) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if indent {
		enc.SetIndent("", "  ")
	}
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	// Encoder adds trailing newline; Python dumps does not for print, but file write is fine either way.
	out := bytes.TrimRight(buf.Bytes(), "\n")
	return out, nil
}

func writeStatus(payload Status) {
	_ = os.MkdirAll(cacheDir, 0o755)
	b, err := encodeJSON(payload, true)
	if err != nil {
		return
	}
	tmp := statusPath + ".tmp"
	if err := os.WriteFile(tmp, append(b, '\n'), 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, statusPath)
}

func printStatus(payload Status) {
	b, err := encodeJSON(payload, false)
	if err != nil {
		return
	}
	os.Stdout.Write(append(b, '\n'))
}

func loadPics() picsData {
	b, err := os.ReadFile(picsPath)
	if err != nil {
		return picsData{Apps: map[string]picsAppRemote{}}
	}
	var data picsData
	if err := json.Unmarshal(b, &data); err != nil {
		return picsData{Apps: map[string]picsAppRemote{}}
	}
	if data.Apps == nil {
		data.Apps = map[string]picsAppRemote{}
	}
	return data
}

func savePics(data picsData) {
	_ = os.MkdirAll(cacheDir, 0o755)
	b, err := encodeJSON(data, true)
	if err != nil {
		return
	}
	tmp := picsPath + ".tmp"
	if err := os.WriteFile(tmp, append(b, '\n'), 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, picsPath)
}

func atoi64(s string) int64 {
	n, _ := strconv.ParseInt(s, 10, 64)
	return n
}

func boolPtr(v bool) *bool { return &v }

func collect() Status {
	buildingPID := lockPID()
	targetID, targetName := readTarget()
	buildingName := ""
	if buildingPID != 0 {
		buildingName = targetName
	}
	pics := loadPics()
	picsApps := pics.Apps
	picsTS := pics.TS
	var games []Game
	live := runningAppIDs(psArgs())
	steamFoss := fossilizeAppIDs()
	steamProgs := steamShaderProgress()

	for _, man := range iterManifests() {
		base := filepath.Base(man)
		appid := strings.TrimPrefix(strings.TrimSuffix(base, ".acf"), "appmanifest_")
		b, err := os.ReadFile(man)
		if err != nil {
			continue
		}
		vals := acfValues(string(b))
		name := vals["name"]
		if name == "" {
			name = appid
		}
		installdir := vals["installdir"]
		if isHidden(appid) || isTool(name, installdir) {
			continue
		}
		lastUpdated := atoi64(vals["LastUpdated"])
		state := int(atoi64(vals["StateFlags"]))
		toDL := atoi64(vals["BytesToDownload"])
		got := atoi64(vals["BytesDownloaded"])
		toStage := atoi64(vals["BytesToStage"])
		staged := atoi64(vals["BytesStaged"])
		bytesLeft := (toDL > 0 && got < toDL) || (toStage > 0 && staged < toStage)
		updating := (state&stateBusy) != 0 || bytesLeft
		if updating && toDL <= 0 && toStage > 0 {
			toDL, got = toStage, staged
		}
		_, steamHere := steamFoss[appid]
		installed := (state&4) != 0 || fileExists(man)
		patchQueued := (state&stateUpdateRequired) != 0 && !updating
		shader := shaderDir(appid)
		var nvidia string
		if shader != "" {
			nvidia = filepath.Join(shader, "nvidiav1")
		}
		nvidiaBytes := int64(0)
		nvidiaMtime := int64(0)
		if nvidia != "" {
			nvidiaBytes = dirSize(nvidia)
			nvidiaMtime = newestMtime(nvidia)
		}
		cacheBytes := nvidiaBytes
		installBytes := atoi64(vals["SizeOnDisk"])
		var foz, replay string
		if shader != "" {
			foz, replay, _ = fozBundle(shader)
		}
		fozMtime := int64(0)
		fozSz := int64(0)
		if foz != "" {
			if st, err := os.Stat(foz); err == nil {
				fozMtime = st.ModTime().Unix()
				fozSz = st.Size()
			}
		}
		replaySz, replayMtime := replayStats(foz)
		if replay != "" && replaySz == 0 {
			if st, err := os.Stat(replay); err == nil {
				replaySz = st.Size()
				replayMtime = st.ModTime().Unix()
			}
		}
		mergedSz := mergedNvidiaBytes(nvidia)
		cacheMtime := nvidiaMtime
		if replayMtime > cacheMtime {
			cacheMtime = replayMtime
		}
		done := replayComplete(foz, replay)
		nvidiaMin := int64(32 * 1024 * 1024)
		if fozSz >= 256*1024*1024 {
			nvidiaMin = 512 * 1024 * 1024
			if fozSz/4 > nvidiaMin {
				nvidiaMin = fozSz / 4
			}
		}
		packMtime := fozMtime
		if lastUpdated > packMtime {
			packMtime = lastUpdated
		}
		nvidiaAfterPack := nvidiaBytes >= nvidiaMin && (packMtime == 0 || nvidiaMtime+120 >= packMtime)
		mergedAfterPack := mergedSz >= nvidiaMin && (packMtime == 0 || nvidiaMtime+120 >= packMtime)
		nvidiaFresh := (nvidiaAfterPack || mergedAfterPack) && (fozSz < 256*1024*1024 || done)
		fozNewer := fozMtime != 0 && nvidiaMtime != 0 && nvidiaMtime+120 < fozMtime

		thisBuilding := buildingPID != 0 && (appid == targetID || (targetID == "" && buildingName == ""))
		var steamLine *steamProg
		if steamHere {
			if sp, ok := steamProgs[appid]; ok {
				steamLine = &sp
			}
		}

		var shaders, detail string
		switch {
		case updating:
			shaders = "blocked"
			if toDL > 0 && got < toDL {
				detail = "Steam качает " + fmtBytes(got) + " / " + fmtBytes(toDL)
			} else if toStage > 0 && staged < toStage {
				detail = "Steam стейджит " + fmtBytes(staged) + " / " + fmtBytes(toStage)
			} else {
				detail = "игра обновляется"
			}
		case steamHere:
			shaders = "building"
			buildingName = name
			if steamLine != nil {
				detail = "Steam собирает " + strconv.FormatFloat(steamLine.Percent, 'f', 0, 64) + "% (" +
					strconv.Itoa(steamLine.Done) + "/" + strconv.Itoa(steamLine.Total) + ")"
			} else {
				detail = "Steam собирает шейдеры"
			}
		case thisBuilding:
			shaders = "building"
			if targetName != "" {
				buildingName = targetName
			} else {
				buildingName = name
			}
			prog := lastProgress()
			if prog != "" {
				detail = "собираю " + prog
			} else {
				detail = "собираю без запуска игры"
			}
		case foz != "" && fozSz >= 256*1024*1024 && !done:
			shaders = "stale"
			if fozNewer {
				detail = "пакет шейдеров Steam новее NVIDIA — " + fmtBytes(nvidiaBytes) + " / FOZ " + fmtBytes(fozSz)
			} else if nvidiaBytes != 0 {
				detail = "FOZ не прогнан — NVIDIA " + fmtBytes(nvidiaBytes) + " / FOZ " + fmtBytes(fozSz)
			} else {
				detail = "FOZ " + fmtBytes(fozSz) + " не прогнан"
			}
		case nvidiaFresh:
			shaders = "ready"
			detail = "кэш NVIDIA на месте"
		case done:
			shaders = "ready"
			detail = "Steam-кэш собран"
		case lastUpdated != 0 && cacheMtime != 0 && cacheMtime+120 < lastUpdated:
			shaders = "stale"
			detail = "игра новее кэша шейдеров"
		case foz != "" && fozSz < 16*1024*1024 && nvidiaBytes >= 32*1024*1024:
			shaders = "ready"
			detail = "мелкий FOZ, кэш NVIDIA на месте"
		case foz != "" && (replay == "" || replayMtime+30 < fozMtime):
			shaders = "stale"
			detail = "FOZ скачан, пайплайны не прогнаны"
		case nvidiaBytes < 32*1024*1024:
			shaders = "missing"
			detail = "кэша ещё нет"
		default:
			shaders = "stale"
			detail = "кэш NVIDIA " + fmtBytes(nvidiaBytes) + ", сборка не догнана"
		}

		_, running := live[appid]
		fozBytes := fozSz
		localBuild := vals["buildid"]
		var remote *picsAppRemote
		if r, ok := picsApps[appid]; ok {
			remote = &r
		}
		remoteBuild := ""
		if remote != nil {
			remoteBuild = remote.BuildID
		}
		var gameCurrent *bool
		if remoteBuild != "" {
			gc := localBuild != "" && remoteBuild == localBuild && !updating
			gameCurrent = &gc
			if !gc && !updating {
				lb := localBuild
				if lb == "" {
					lb = "нет"
				}
				detail = "Steam build " + remoteBuild + ", локально " + lb
				if shaders == "ready" {
					shaders = "stale"
				}
			}
		} else if patchQueued {
			gameCurrent = boolPtr(false)
			if shaders == "ready" {
				shaders = "stale"
			}
			if !strings.Contains(detail, "обновляется") {
				detail = "Steam ждёт патч"
			}
		}
		shadersOk := shaders == "ready" && (gameCurrent == nil || *gameCurrent)
		canBuild := foz != "" && !running && !updating && !steamHere

		var buildPercent float64
		if shaders == "building" {
			if steamLine != nil {
				buildPercent = steamLine.Percent
			} else if thisBuilding {
				buildPercent = progressPercent()
			}
		}
		downloadPercent := 0.0
		if toDL > 0 {
			downloadPercent = math.Min(100.0, 100.0*float64(got)/float64(toDL))
		}

		var action string
		switch {
		case shaders == "building":
			if buildPercent != 0 {
				action = strconv.FormatFloat(buildPercent, 'f', 0, 64) + "%"
			} else {
				action = "Steam"
			}
		case updating:
			if toDL != 0 {
				action = strconv.FormatFloat(downloadPercent, 'f', 0, 64) + "%"
			} else {
				action = "качаю"
			}
		case running:
			action = "в игре"
		case gameCurrent != nil && !*gameCurrent:
			action = "Патч"
		case foz == "":
			action = ""
		case shaders == "stale" || shaders == "missing":
			action = "Собрать"
		default:
			action = "Ещё раз"
		}

		checkedAt := picsTS
		if remote != nil && remote.FetchedAt != 0 {
			checkedAt = remote.FetchedAt
		}

		games = append(games, Game{
			ID:              appid,
			Name:            name,
			Kind:            gameKind(appid, filepath.Dir(man), installdir),
			Installed:       installed,
			Updated:         installed && !updating,
			Updating:        updating,
			Running:         running,
			BuildID:          localBuild,
			GameLatest:      remoteBuild,
			GameCurrent:     gameCurrent,
			ShadersOk:       shadersOk,
			CheckedAt:       checkedAt,
			LastUpdated:     lastUpdated,
			Shaders:         shaders,
			InstallBytes:    installBytes,
			CacheBytes:      cacheBytes,
			NvidiaBytes:     nvidiaBytes,
			FozBytes:        fozBytes,
			FozNewer:        fozNewer,
			DownloadBytes:   got,
			DownloadTotal:   toDL,
			DownloadPercent: math.Round(downloadPercent*10) / 10,
			BuildPercent:    buildPercent,
			Detail:          detail,
			Action:          action,
			CanBuild:        canBuild,
		})
	}

	// Python tuple key: False < True, so updating/building/outdated/stale/missing first.
	sort.SliceStable(games, func(i, j int) bool {
		lessBool := func(a, b bool) (lt, decided bool) {
			if a != b {
				return !a && b, true
			}
			return false, false
		}
		a, b := games[i], games[j]
		keysA := []bool{!a.Updating, a.Shaders != "building", a.GameCurrent == nil || *a.GameCurrent, a.Shaders != "stale", a.Shaders != "missing"}
		keysB := []bool{!b.Updating, b.Shaders != "building", b.GameCurrent == nil || *b.GameCurrent, b.Shaders != "stale", b.Shaders != "missing"}
		for k := range keysA {
			if lt, decided := lessBool(keysA[k], keysB[k]); decided {
				return lt
			}
		}
		return strings.ToLower(a.Name) < strings.ToLower(b.Name)
	})

	stale := false
	for _, g := range games {
		if g.Shaders == "stale" || g.Shaders == "missing" || g.Shaders == "building" || (g.GameCurrent != nil && !*g.GameCurrent) {
			stale = true
			break
		}
	}
	var downloading []Game
	for _, g := range games {
		if g.Updating {
			downloading = append(downloading, g)
		}
	}
	var compiling *Game
	for i := range games {
		if games[i].Shaders == "building" {
			compiling = &games[i]
			break
		}
	}
	barPercent := 0.0
	barKind := ""
	barName := ""
	if compiling != nil {
		barKind = "compile"
		barName = compiling.Name
		barPercent = compiling.BuildPercent
	} else if len(downloading) > 0 {
		barKind = "download"
		barName = downloading[0].Name
		barPercent = downloading[0].DownloadPercent
	} else {
		for _, g := range games {
			if g.GameCurrent != nil && !*g.GameCurrent {
				barKind = "patch"
				barName = g.Name
				break
			}
		}
		if barKind == "" && stale {
			barKind = "shaders"
		}
	}

	outBuildingName := buildingName
	if outBuildingName == "" && compiling != nil {
		outBuildingName = compiling.Name
	}
	updatingName := ""
	downloadPct := 0.0
	if len(downloading) > 0 {
		updatingName = downloading[0].Name
		downloadPct = downloading[0].DownloadPercent
	}

	if games == nil {
		games = []Game{}
	}

	return Status{
		TS:              time.Now().Unix(),
		Building:        buildingPID != 0 || len(steamFoss) > 0,
		BuildingPid:     buildingPID,
		BuildingName:    outBuildingName,
		CheckedAt:       picsTS,
		Stale:           stale,
		Updating:        len(downloading) > 0,
		UpdatingName:    updatingName,
		DownloadPercent: downloadPct,
		BarKind:         barKind,
		BarName:         barName,
		BarPercent:      barPercent,
		Games:           games,
	}
}

func cmdStatus() int {
	payload := collect()
	writeStatus(payload)
	printStatus(payload)
	return 0
}
