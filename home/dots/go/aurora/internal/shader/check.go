package shader

import (
	"encoding/json"
	"io"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"
)

func fetchPublicBuild(appid string) *picsAppRemote {
	client := &http.Client{Timeout: 12 * time.Second}
	req, err := http.NewRequest(http.MethodGet, "https://api.steamcmd.net/v1/info/"+appid, nil)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", "aurora-shader-ctl")
	resp, err := client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}
	var data struct {
		Data map[string]struct {
			Depots struct {
				Branches map[string]struct {
					BuildID           string `json:"buildid"`
					TimeUpdated       any    `json:"timeupdated"`
					TimeBuildUpdated  any    `json:"timebuildupdated"`
				} `json:"branches"`
			} `json:"depots"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil
	}
	app, ok := data.Data[appid]
	if !ok {
		return nil
	}
	public, ok := app.Depots.Branches["public"]
	if !ok {
		return nil
	}
	buildid := public.BuildID
	if buildid == "" {
		return nil
	}
	tu := anyToInt64(public.TimeUpdated)
	if tu == 0 {
		tu = anyToInt64(public.TimeBuildUpdated)
	}
	return &picsAppRemote{
		BuildID:     buildid,
		TimeUpdated: tu,
		FetchedAt:   time.Now().Unix(),
	}
}

func anyToInt64(v any) int64 {
	switch t := v.(type) {
	case float64:
		return int64(t)
	case string:
		return atoi64(t)
	case json.Number:
		n, _ := t.Int64()
		return n
	default:
		return 0
	}
}

func steamInstall(appid string) bool {
	for _, cmd := range [][]string{
		{"xdg-open", "steam://install/" + appid},
		{"steam", "steam://install/" + appid},
	} {
		c := exec.Command(cmd[0], cmd[1:]...)
		c.Stdout = nil
		c.Stderr = nil
		c.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
		if err := c.Start(); err == nil {
			return true
		}
	}
	return false
}

func cmdCheck(appid string, quiet bool) int {
	payload := collect()
	var ids []string
	if appid != "" {
		ids = []string{appid}
	} else {
		for _, g := range payload.Games {
			ids = append(ids, g.ID)
		}
	}
	pics := loadPics()
	if pics.Apps == nil {
		pics.Apps = map[string]picsAppRemote{}
	}
	var failed []string
	var mu sync.Mutex
	workers := len(ids)
	if workers > 4 {
		workers = 4
	}
	if workers < 1 {
		workers = 1
	}
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup
	for _, id := range ids {
		wg.Add(1)
		sem <- struct{}{}
		go func(i string) {
			defer wg.Done()
			defer func() { <-sem }()
			info := fetchPublicBuild(i)
			mu.Lock()
			defer mu.Unlock()
			if info != nil {
				pics.Apps[i] = *info
			} else {
				failed = append(failed, i)
			}
		}(id)
	}
	wg.Wait()
	pics.TS = time.Now().Unix()
	savePics(pics)
	payload = collect()
	payload.CheckedAt = pics.TS
	if failed == nil {
		failed = []string{}
	}
	payload.CheckFailed = &failed
	writeStatus(payload)
	names := map[string]string{}
	for _, g := range payload.Games {
		names[g.ID] = g.Name
	}
	var outdated []string
	for _, g := range payload.Games {
		if g.GameCurrent != nil && !*g.GameCurrent {
			outdated = append(outdated, g.Name)
		}
	}
	if !quiet {
		if len(failed) > 0 {
			var label []string
			for _, i := range failed {
				if n, ok := names[i]; ok {
					label = append(label, n)
				} else {
					label = append(label, i)
				}
			}
			notify("Steam", "Не достучался: "+strings.Join(label, ", "))
		} else if len(outdated) > 0 {
			notify("Steam", "Есть патч: "+strings.Join(outdated, ", "))
		} else {
			notify("Steam", "Игры свежие — сверка с Steam PICS")
		}
		printStatus(payload)
	}
	if len(failed) > 0 {
		return 1
	}
	return 0
}

func cmdUpdate(appid string) int {
	_ = cmdCheck(appid, true)
	payload := collect()
	var targets []Game
	for _, g := range payload.Games {
		if appid == "" || g.ID == appid {
			targets = append(targets, g)
		}
	}
	if len(targets) == 0 {
		notify("Шейдеры", "Игра не найдена")
		printStatus(payload)
		return 1
	}
	var launched []string
	var needBuild []string
	steamFoss := fossilizeAppIDs()
	for _, game := range targets {
		_, foss := steamFoss[game.ID]
		if game.Updating || foss {
			if game.Updating && steamInstall(game.ID) {
				launched = append(launched, game.Name)
			}
			continue
		}
		if game.GameCurrent != nil && !*game.GameCurrent {
			if steamInstall(game.ID) {
				launched = append(launched, game.Name)
			}
			continue
		}
		if game.Shaders == "stale" || game.Shaders == "missing" || game.Shaders == "building" || !game.ShadersOk {
			if game.CanBuild || game.FozBytes != 0 {
				needBuild = append(needBuild, game.ID)
			}
		}
	}
	if len(launched) > 0 {
		notify("Steam", "Качаю патч: "+strings.Join(launched, ", "))
	}
	if len(needBuild) == 0 {
		writeStatus(collect())
		printStatus(collect())
		return 0
	}
	if appid != "" {
		return cmdBuild(appid)
	}
	if len(needBuild) == 1 {
		return cmdBuild(needBuild[0])
	}
	return cmdBuild("")
}
