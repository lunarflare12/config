package lab

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"aurora/internal/execx"
)

var appProjects = map[string]bool{
	"apps-isolated": true, "telegram-isolated": true, "steam-isolated": true,
}

var appContainers = map[string]bool{
	"chrome-dd": true, "chrome-az": true, "chrome-hika": true, "chrome-sciencesoft": true,
	"firefox": true, "zen": true, "idea": true, "spotify": true, "vscode": true,
	"obsidian": true, "openlens": true, "libreoffice": true, "telegram-1": true,
	"telegram-2": true, "steam": true, "overwatch": true, "terraria": true, "albion": true,
}

type containerRow struct {
	Name     string   `json:"name"`
	Image    string   `json:"image"`
	Status   string   `json:"status"`
	ID       string   `json:"id"`
	State    string   `json:"state"`
	CPU      string   `json:"cpu"`
	Mem      string   `json:"mem"`
	MemPerc  string   `json:"memPerc"`
	Net      string   `json:"net"`
	Volumes  []string `json:"volumes"`
	Networks []string `json:"networks"`
}

func parseContainerState(status, state string) string {
	st := strings.ToLower(strings.TrimSpace(state))
	text := strings.ToLower(strings.TrimSpace(status))
	if st == "paused" || strings.Contains(text, "paused") {
		return "paused"
	}
	if st == "running" || strings.HasPrefix(text, "up") {
		return "running"
	}
	if st != "" {
		return st
	}
	if strings.HasPrefix(text, "exited") || strings.Contains(text, "dead") {
		return "exited"
	}
	return "unknown"
}

func containerStats() map[string]map[string]string {
	code, text, _ := run(12*time.Second, "docker", "stats", "--no-stream", "--format",
		"{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}")
	out := map[string]map[string]string{}
	if code != 0 {
		return out
	}
	for _, line := range strings.Split(text, "\n") {
		parts := strings.Split(line, "\t")
		if len(parts) < 3 {
			continue
		}
		row := map[string]string{"cpu": strings.TrimSpace(parts[1]), "mem": strings.TrimSpace(parts[2])}
		if len(parts) > 3 {
			row["memPerc"] = strings.TrimSpace(parts[3])
		}
		if len(parts) > 4 {
			row["net"] = strings.TrimSpace(parts[4])
		}
		out[parts[0]] = row
	}
	return out
}

func isAppContainer(name, project string) bool {
	if appProjects[project] {
		return true
	}
	return appContainers[name]
}

func containerInspect(names []string) map[string]map[string]any {
	if len(names) == 0 {
		return nil
	}
	args := append([]string{"inspect"}, names...)
	code, text, _ := run(10*time.Second, "docker", args...)
	if code != 0 || strings.TrimSpace(text) == "" {
		return nil
	}
	var data []map[string]any
	if json.Unmarshal([]byte(text), &data) != nil {
		return nil
	}
	out := map[string]map[string]any{}
	for _, obj := range data {
		name := strings.TrimPrefix(strVal(obj["Name"]), "/")
		if name == "" {
			continue
		}
		var mounts []string
		for _, m := range toSlice(obj["Mounts"]) {
			mount := strMap(m)
			src := orDefault(strVal(mount["Source"]), strVal(mount["Name"]))
			dst := strVal(mount["Destination"])
			switch {
			case src != "" && dst != "":
				mounts = append(mounts, src+" → "+dst)
			case dst != "":
				mounts = append(mounts, dst)
			}
		}
		var nets []string
		ns := strMap(strMap(obj["NetworkSettings"])["Networks"])
		for netName, info := range ns {
			ip := strVal(strMap(info)["IPAddress"])
			line := netName
			if ip != "" {
				line += "  " + ip
			}
			if line != "" {
				nets = append(nets, line)
			}
		}
		out[name] = map[string]any{"volumes": mounts, "networks": nets}
	}
	return out
}

func listDocker(full bool) ([]containerRow, []containerRow) {
	_ = full
	code, text, _ := run(5*time.Second, "docker", "ps", "-a", "--format",
		"{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ID}}\t{{.State}}\t{{.Label \"com.docker.compose.project\"}}")
	if code != 0 {
		return nil, nil
	}
	stats := containerStats()
	type rowT struct {
		name, project string
		parts         []string
	}
	var rows []rowT
	for _, line := range strings.Split(text, "\n") {
		parts := strings.Split(line, "\t")
		if len(parts) < 3 {
			continue
		}
		project := ""
		if len(parts) > 5 {
			project = strings.TrimSpace(parts[5])
		}
		rows = append(rows, rowT{name: parts[0], project: project, parts: parts})
	}
	names := make([]string, len(rows))
	for i, r := range rows {
		names[i] = r.name
	}
	details := containerInspect(names)
	var lab, apps []containerRow
	for _, r := range rows {
		parts := r.parts
		ident := ""
		if len(parts) > 3 && len(parts[3]) >= 12 {
			ident = parts[3][:12]
		}
		stateVal := ""
		if len(parts) > 4 {
			stateVal = parts[4]
		}
		state := parseContainerState(parts[2], stateVal)
		usage := stats[r.name]
		extra := details[r.name]
		cpu, mem, memPerc, netIO := "", "", "", ""
		if usage != nil {
			cpu, mem = usage["cpu"], usage["mem"]
			memPerc, netIO = usage["memPerc"], usage["net"]
		}
		vols, nets := []string{}, []string{}
		if extra != nil {
			for _, v := range toSlice(extra["volumes"]) {
				vols = append(vols, strVal(v))
			}
			for _, n := range toSlice(extra["networks"]) {
				nets = append(nets, strVal(n))
			}
		}
		item := containerRow{
			Name: r.name, Image: parts[1], Status: parts[2], ID: ident, State: state,
			CPU: cpu, Mem: mem, MemPerc: memPerc, Net: netIO, Volumes: vols, Networks: nets,
		}
		if isAppContainer(r.name, r.project) {
			apps = append(apps, item)
		} else {
			lab = append(lab, item)
		}
	}
	sort.Slice(lab, func(i, j int) bool { return lab[i].Name < lab[j].Name })
	sort.Slice(apps, func(i, j int) bool { return apps[i].Name < apps[j].Name })
	return lab, apps
}

func dropContainerWindows(name, action string) {
	skip := map[string]bool{
		"steam": true, "overwatch": true, "terraria": true, "albion": true,
		"ollama": true, "omniroute": true,
	}
	if skip[name] {
		return
	}
	aurora := execx.Look("aurora")
	if aurora == "" {
		aurora = filepath.Join(execx.Home(), ".config/scripts/aurora")
	}
	if st, err := os.Stat(aurora); err != nil || st.IsDir() {
		return
	}
	_, _, _ = run(2*time.Second, aurora, "reaper", name, action)
}

func dockerAction(action, name string) int {
	if !nameRE.MatchString(name) {
		_, _ = os.Stderr.WriteString("invalid name\n")
		return 2
	}
	var cmd []string
	switch action {
	case "pause":
		if appContainers[name] && name != "steam" && name != "overwatch" {
			dropContainerWindows(name, "stop")
			_, _, _ = run(10*time.Second, "docker", "update", "--restart", "no", name)
			cmd = []string{"docker", "stop", "-t", "0", name}
		} else {
			cmd = []string{"docker", "pause", name}
		}
	case "unpause":
		cmd = []string{"docker", "unpause", name}
	case "start":
		cmd = []string{"docker", "start", name}
	case "stop":
		dropContainerWindows(name, "stop")
		_, _, _ = run(10*time.Second, "docker", "update", "--restart", "no", name)
		cmd = []string{"docker", "stop", "-t", "0", name}
	case "restart":
		cmd = []string{"docker", "restart", name}
	case "rm":
		dropContainerWindows(name, "kill")
		cmd = []string{"docker", "rm", "-f", name}
	default:
		_, _ = os.Stderr.WriteString("invalid docker action\n")
		return 2
	}
	code, out, err := run(40*time.Second, cmd[0], cmd[1:]...)
	if action == "stop" || action == "pause" || action == "rm" {
		dropContainerWindows(name, "stop")
	}
	emit(out, err)
	return code
}
