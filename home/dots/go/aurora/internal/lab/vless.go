package lab

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

const vlessRun = "/run/aurora-vless"

func vlessPIDPath(name string) string {
	return filepath.Join(vlessRun, name+".pid")
}

func vlessRuntimeConfig(name string) string {
	return filepath.Join(vlessRun, name+".json")
}

func vlessUp(name string) bool {
	pidPath := vlessPIDPath(name)
	b, err := os.ReadFile(pidPath)
	if err != nil {
		return false
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil {
		return false
	}
	if err := syscall.Kill(pid, 0); err != nil {
		if err != syscall.EPERM {
			_ = os.Remove(pidPath)
			return false
		}
	}
	cmdline, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return false
	}
	cmd := strings.ReplaceAll(string(cmdline), "\x00", " ")
	return strings.Contains(cmd, name) && (strings.Contains(cmd, "sing-box") || strings.Contains(cmd, "xray"))
}

func vlessConfigs() []tunnelRow {
	seen := map[string]bool{}
	var out []tunnelRow
	for _, directory := range vlessDirs {
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
			if !stringsHasSuffix(filename, ".json") {
				continue
			}
			stem := filename[:len(filename)-5]
			if !nameRE.MatchString(stem) || seen[stem] {
				continue
			}
			path := filepath.Join(directory, filename)
			label, folder := jsonMeta(path)
			seen[stem] = true
			out = append(out, tunnelRow{
				Name:   stem,
				Label:  orDefault(label, stem),
				Folder: orDefault(folder, "personal"),
				Up:     vlessUp(stem),
				Path:   path,
				Kind:   "vless",
			})
		}
	}
	return out
}

func singboxBin() string {
	user := os.Getenv("USER")
	if user == "" {
		user = "dd"
	}
	candidates := []string{
		execx.Look("sing-box"),
		filepath.Join(execx.Home(), ".local/bin/sing-box"),
		"/run/current-system/sw/bin/sing-box",
		"/etc/profiles/per-user/" + user + "/bin/sing-box",
	}
	if globs, _ := filepath.Glob("/nix/store/*-sing-box-*/bin/sing-box"); len(globs) > 0 {
		sort.Sort(sort.Reverse(sort.StringSlice(globs)))
		candidates = append(candidates, globs...)
	}
	for _, cand := range candidates {
		if cand == "" {
			continue
		}
		st, err := os.Stat(cand)
		if err == nil && !st.IsDir() && st.Mode()&0o111 != 0 {
			return cand
		}
	}
	return "sing-box"
}

func isSingbox(cfg map[string]any) bool {
	for _, key := range []string{"inbounds", "outbounds"} {
		rows, _ := cfg[key].([]any)
		for _, row := range rows {
			m, _ := row.(map[string]any)
			if m == nil {
				continue
			}
			if m["type"] != nil && m["protocol"] == nil {
				return true
			}
		}
	}
	return false
}

func strMap(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func strVal(v any) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	case float64:
		return strconv.FormatInt(int64(t), 10)
	default:
		return fmt.Sprint(v)
	}
}

func intVal(v any, def int) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	case string:
		n, _ := strconv.Atoi(t)
		if n != 0 {
			return n
		}
	}
	return def
}

func xrayToSingbox(cfg map[string]any) map[string]any {
	if isSingbox(cfg) {
		return cfg
	}
	var inbounds []any
	for _, row := range toSlice(cfg["inbounds"]) {
		ib := strMap(row)
		proto := strVal(ib["protocol"])
		if proto == "" {
			proto = strVal(ib["type"])
		}
		if proto == "" {
			proto = "socks"
		}
		if proto == "tun" || strVal(ib["type"]) == "tun" {
			inbounds = append(inbounds, ib)
			continue
		}
		item := map[string]any{
			"type":        proto,
			"tag":         orDefault(strVal(ib["tag"]), proto+"-in"),
			"listen":      orDefault(strVal(ib["listen"]), "127.0.0.1"),
			"listen_port": intVal(ib["listen_port"], intVal(ib["port"], 10818)),
		}
		inbounds = append(inbounds, item)
	}
	if len(inbounds) == 0 {
		inbounds = append(inbounds, map[string]any{
			"type": "socks", "tag": "socks-in", "listen": "127.0.0.1", "listen_port": 10818,
		})
	}
	var outbounds []any
	for _, row := range toSlice(cfg["outbounds"]) {
		ob := strMap(row)
		proto := strVal(ob["protocol"])
		if proto == "" {
			proto = strVal(ob["type"])
		}
		switch proto {
		case "freedom", "direct":
			outbounds = append(outbounds, map[string]any{"type": "direct", "tag": orDefault(strVal(ob["tag"]), "direct")})
			continue
		case "blackhole", "block":
			outbounds = append(outbounds, map[string]any{"type": "block", "tag": orDefault(strVal(ob["tag"]), "block")})
			continue
		}
		if proto != "vless" {
			if ob["type"] != nil {
				outbounds = append(outbounds, ob)
			}
			continue
		}
		settings := strMap(ob["settings"])
		vnext := strMap(firstMap(settings["vnext"]))
		user := strMap(firstMap(vnext["users"]))
		ss := strMap(ob["streamSettings"])
		reality := strMap(ss["realitySettings"])
		tlsSet := strMap(ss["tlsSettings"])
		item := map[string]any{
			"type":        "vless",
			"tag":         orDefault(strVal(ob["tag"]), "proxy"),
			"server":      orDefault(strVal(vnext["address"]), strVal(ob["server"])),
			"server_port": intVal(vnext["port"], intVal(ob["server_port"], 443)),
			"uuid":        orDefault(strVal(user["id"]), strVal(user["uuid"])),
		}
		if flow := orDefault(strVal(user["flow"]), strVal(ob["flow"])); flow != "" {
			item["flow"] = flow
			item["packet_encoding"] = "xudp"
		}
		security := strVal(ss["security"])
		if security == "reality" || len(reality) > 0 {
			item["tls"] = map[string]any{
				"enabled":     true,
				"server_name": orDefault(strVal(reality["serverName"]), strVal(reality["server_name"])),
				"utls": map[string]any{
					"enabled":     true,
					"fingerprint": orDefault(strVal(reality["fingerprint"]), "chrome"),
				},
				"reality": map[string]any{
					"enabled":    true,
					"public_key": orDefault(strVal(reality["publicKey"]), strVal(reality["public_key"])),
					"short_id":   orDefault(strVal(reality["shortId"]), strVal(reality["short_id"])),
				},
			}
		} else if security == "tls" {
			item["tls"] = map[string]any{
				"enabled":     true,
				"server_name": orDefault(strVal(tlsSet["serverName"]), strVal(tlsSet["server_name"])),
			}
		}
		network := orDefault(strVal(ss["network"]), "tcp")
		switch network {
		case "ws":
			ws := strMap(ss["wsSettings"])
			item["transport"] = map[string]any{"type": "ws", "path": orDefault(strVal(ws["path"]), "/")}
		case "grpc":
			grpc := strMap(ss["grpcSettings"])
			item["transport"] = map[string]any{"type": "grpc", "service_name": strVal(grpc["serviceName"])}
		}
		outbounds = append(outbounds, item)
	}
	hasDirect := false
	for _, row := range outbounds {
		if strMap(row)["type"] == "direct" {
			hasDirect = true
			break
		}
	}
	if !hasDirect {
		outbounds = append(outbounds, map[string]any{"type": "direct", "tag": "direct"})
	}
	return map[string]any{
		"log":       map[string]any{"level": "warn"},
		"inbounds":  inbounds,
		"outbounds": outbounds,
	}
}

func toSlice(v any) []any {
	s, _ := v.([]any)
	return s
}

func firstMap(v any) map[string]any {
	s := toSlice(v)
	if len(s) == 0 {
		return map[string]any{}
	}
	return strMap(s[0])
}

func vlessListenPort(cfg map[string]any) int {
	for _, row := range toSlice(cfg["inbounds"]) {
		ib := strMap(row)
		kind := orDefault(strVal(ib["type"]), strVal(ib["protocol"]))
		if kind == "tun" {
			return 0
		}
		port := intVal(ib["listen_port"], intVal(ib["port"], 0))
		if port > 0 {
			return port
		}
	}
	return 10818
}

func waitVlessReady(cmd *exec.Cmd, port int) bool {
	if port <= 0 {
		for i := 0; i < 25; i++ {
			if cmd.ProcessState != nil && !cmd.ProcessState.Exited() {
				// not started yet
			}
			if cmd.Process != nil {
				if _, err := os.FindProcess(cmd.Process.Pid); err == nil {
					// poll via wait channel would block — check /proc
					if _, err := os.Stat(filepath.Join("/proc", strconv.Itoa(cmd.Process.Pid))); err != nil {
						return false
					}
				}
			}
			time.Sleep(80 * time.Millisecond)
		}
		return cmd.Process != nil
	}
	for i := 0; i < 25; i++ {
		if cmd.Process != nil {
			if _, err := os.Stat(filepath.Join("/proc", strconv.Itoa(cmd.Process.Pid))); err != nil {
				return false
			}
		}
		conn, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)), 150*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return true
		}
		time.Sleep(80 * time.Millisecond)
	}
	return cmd.Process != nil
}

func stopVlessPID(pidPath string) {
	b, err := os.ReadFile(pidPath)
	if err != nil {
		return
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil {
		return
	}
	if err := syscall.Kill(-pid, syscall.SIGTERM); err != nil {
		_ = syscall.Kill(pid, syscall.SIGTERM)
	}
	_ = os.Remove(pidPath)
}

func toggleVless(name string) int {
	if !nameRE.MatchString(name) {
		fmt.Fprintln(os.Stderr, "invalid name")
		return 2
	}
	var row *tunnelRow
	for _, item := range vlessConfigs() {
		if item.Name == name {
			r := item
			row = &r
			break
		}
	}
	if row == nil {
		fmt.Fprintln(os.Stderr, "vless config not found")
		return 1
	}
	_ = os.MkdirAll(vlessRun, 0o755)
	pidPath := vlessPIDPath(name)
	if row.Up {
		stopVlessPID(pidPath)
		_ = os.Remove(vlessRuntimeConfig(name))
		return 0
	}
	binPath := singboxBin()
	raw, err := os.ReadFile(row.Path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot read config: %v\n", err)
		return 1
	}
	clean := stripHashPreamble(string(raw))
	var parsed map[string]any
	if err := json.Unmarshal([]byte(clean), &parsed); err != nil {
		fmt.Fprintf(os.Stderr, "invalid vless json: %v\n", err)
		return 1
	}
	runtimeCfg := xrayToSingbox(parsed)
	port := vlessListenPort(runtimeCfg)
	runtime := vlessRuntimeConfig(name)
	out, err := json.MarshalIndent(runtimeCfg, "", "  ")
	if err != nil {
		return 1
	}
	if err := os.WriteFile(runtime, append(out, '\n'), 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "cannot write runtime config: %v\n", err)
		return 1
	}
	logPath := filepath.Join(vlessRun, name+".log")
	logFh, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		logFh = nil
	}
	cmd := exec.Command(binPath, "run", "-c", runtime)
	if logFh != nil {
		cmd.Stdout = logFh
		cmd.Stderr = logFh
		defer logFh.Close()
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		fmt.Fprintln(os.Stderr, "sing-box binary not found")
		return 1
	}
	_ = os.WriteFile(pidPath, []byte(strconv.Itoa(cmd.Process.Pid)+"\n"), 0o644)
	if !waitVlessReady(cmd, port) {
		msg := "sing-box failed to start"
		if port > 0 {
			msg = fmt.Sprintf("sing-box failed to listen on 127.0.0.1:%d", port)
		}
		fmt.Fprintln(os.Stderr, msg)
		_ = syscall.Kill(cmd.Process.Pid, syscall.SIGTERM)
		return 1
	}
	return 0
}
