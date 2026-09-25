package reaper

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var classOf = map[string][]*regexp.Regexp{
	"chrome-dd":   {regexp.MustCompile(`^chrome-dd$`)},
	"chrome-az":   {regexp.MustCompile(`^chrome-az$`)},
	"chrome-hika": {regexp.MustCompile(`^chrome-hika$`)},
	"vscode":      {regexp.MustCompile(`^(code|Code)$`)},
	"obsidian":    {regexp.MustCompile(`^(md\.Obsidian|obsidian)$`)},
	"openlens":    {regexp.MustCompile(`^(open-lens|OpenLens)$`)},
	"libreoffice": {regexp.MustCompile(`^libreoffice`)},
	"firefox":     {regexp.MustCompile(`^firefox$`)},
	"zen":         {regexp.MustCompile(`^(zen|ZenBrowser)$`)},
	"spotify":     {regexp.MustCompile(`^spotify`)},
	"idea":        {regexp.MustCompile(`^jetbrains-idea`)},
}

var killOf = map[string]string{
	"chrome-dd":   `(^|/)(chrome|google-chrome|chromium)([^-]|$)`,
	"chrome-az":   `(^|/)(chrome|google-chrome|chromium)([^-]|$)`,
	"chrome-hika": `(^|/)(chrome|google-chrome|chromium)([^-]|$)`,
	"vscode":      `(^|/)(code|Code)([^-]|$)`,
	"obsidian":    `obsidian`,
	"openlens":    `open-lens|OpenLens`,
	"libreoffice": `soffice|libreoffice`,
	"firefox":     `firefox`,
	"zen":         `(^|/)zen([^-]|$)`,
	"spotify":     `spotify`,
	"idea":        `idea|jetbrains`,
}

var (
	telegram     = regexp.MustCompile(`^org\.telegram\.desktop`)
	telegramNames = []string{"telegram-1", "telegram-2"}
	keep         = regexp.MustCompile(`(?i)^(cursor|steam|steam_app_|dota2|gamescope)`)
	anr          = regexp.MustCompile(`(?i)not responding|не отвечает|hyprland-dialog`)
	ghost        = regexp.MustCompile(`(?i)chrome_status_icon|status.?notifier|xdg-desktop-portal`)
	deadStates   = map[string]bool{"paused": true, "exited": true, "dead": true, "removing": true, "created": true}
	stopActions  = map[string]bool{"pause": true, "die": true, "stop": true, "kill": true, "oom": true}
	skipEvents   = map[string]bool{"ollama": true, "omniroute": true, "steam": true, "overwatch": true, "terraria": true, "albion": true}
)

type win struct {
	Mapped       *bool    `json:"mapped"`
	Hidden       *bool    `json:"hidden"`
	Size         []int    `json:"size"`
	Class        string   `json:"class"`
	InitialClass string   `json:"initialClass"`
	Title        string   `json:"title"`
	Address      string   `json:"address"`
	PID          int      `json:"pid"`
}

func run(args []string, timeout time.Duration) string {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Stderr = io.Discard
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return string(out)
}

func clients() []win {
	raw := strings.TrimSpace(run([]string{"hyprctl", "-j", "clients"}, 1500*time.Millisecond))
	if raw == "" {
		return nil
	}
	var data []win
	if json.Unmarshal([]byte(raw), &data) != nil {
		return nil
	}
	return data
}

func clsOf(w win) string {
	if w.Class != "" {
		return w.Class
	}
	return w.InitialClass
}

func liveClients() []win {
	var out []win
	for _, w := range clients() {
		if w.Mapped != nil && !*w.Mapped {
			continue
		}
		if w.Hidden != nil && *w.Hidden {
			continue
		}
		area := 0
		if len(w.Size) >= 2 {
			area = w.Size[0] * w.Size[1]
		}
		if area < 64 {
			continue
		}
		c, t := clsOf(w), w.Title
		if ghost.MatchString(c) || ghost.MatchString(t) {
			continue
		}
		out = append(out, w)
	}
	return out
}

func containerStates() map[string]string {
	raw := run([]string{"docker", "ps", "-a", "--format", "{{.Names}}\t{{.State}}"}, 2*time.Second)
	out := map[string]string{}
	for _, line := range strings.Split(raw, "\n") {
		name, state, ok := strings.Cut(line, "\t")
		if !ok {
			continue
		}
		out[strings.TrimSpace(name)] = strings.ToLower(strings.TrimSpace(state))
	}
	return out
}

func pidAlive(pid int) bool {
	if pid <= 1 {
		return false
	}
	_, err := os.Stat("/proc/" + strconv.Itoa(pid))
	return err == nil
}

func addrOf(w win) string {
	a := w.Address
	if a == "" {
		return ""
	}
	if strings.HasPrefix(a, "0x") {
		return a
	}
	return "0x" + a
}

func killAddresses(addrs []string) {
	var clean []string
	for _, a := range addrs {
		if a != "" {
			clean = append(clean, a)
		}
	}
	if len(clean) == 0 {
		return
	}
	var b strings.Builder
	b.WriteString("local n=0")
	for _, addr := range clean {
		b.WriteString(` local w=hl.get_window("address:`)
		b.WriteString(addr)
		b.WriteString(`"); if w then hl.dispatch(hl.dsp.window.close({ window = w })); hl.dispatch(hl.dsp.window.kill({ window = w })); n=n+1 end`)
	}
	b.WriteString(" return n")
	_ = run([]string{"hyprctl", "repl", b.String()}, 1200*time.Millisecond)
}

func classOwner(cls string) string {
	for name, pats := range classOf {
		for _, p := range pats {
			if p.MatchString(cls) {
				return name
			}
		}
	}
	return ""
}

func containerPIDs(name string) []int {
	raw := run([]string{"docker", "top", name, "-eo", "pid"}, 1200*time.Millisecond)
	var pids []int
	for i, line := range strings.Split(raw, "\n") {
		if i == 0 {
			continue
		}
		tok := strings.Fields(line)
		if len(tok) == 0 {
			continue
		}
		if n, err := strconv.Atoi(tok[0]); err == nil {
			pids = append(pids, n)
		}
	}
	return pids
}

func shouldReap(w win, name, action string, states map[string]string, pids map[int]string) bool {
	cls, title := clsOf(w), w.Title
	if keep.MatchString(cls) {
		return false
	}
	if anr.MatchString(cls) || anr.MatchString(title) {
		return true
	}
	pid := w.PID
	owner := pids[pid]
	if owner == "" {
		owner = classOwner(cls)
	}
	if telegram.MatchString(cls) {
		if pid > 1 && pidAlive(pid) && !stopActions[action] {
			return false
		}
		if stopActions[action] && (name == "telegram-1" || name == "telegram-2") {
			return pids[pid] == name || (pid > 1 && !pidAlive(pid))
		}
		if pid > 1 && !pidAlive(pid) {
			return true
		}
		allDead := true
		any := false
		for _, n := range telegramNames {
			if _, ok := states[n]; !ok {
				continue
			}
			any = true
			if !deadStates[states[n]] {
				allDead = false
			}
		}
		return any && allDead
	}
	if stopActions[action] && name != "" && owner == name {
		return true
	}
	if owner != "" && deadStates[states[owner]] {
		return true
	}
	if owner != "" && pid > 1 && !pidAlive(pid) {
		return true
	}
	return false
}

func reap(name, action string) int {
	states := containerStates()
	pids := map[int]string{}
	wanted := map[string]bool{}
	if name != "" {
		wanted[name] = true
	}
	if name == "telegram-1" || name == "telegram-2" || name == "" {
		for _, n := range telegramNames {
			if _, ok := states[n]; ok {
				wanted[n] = true
			}
		}
	}
	if stopActions[action] && name != "" {
		for _, pid := range containerPIDs(name) {
			pids[pid] = name
		}
	}
	for _, tg := range telegramNames {
		if wanted[tg] && states[tg] == "running" {
			for _, pid := range containerPIDs(tg) {
				if _, ok := pids[pid]; !ok {
					pids[pid] = tg
				}
			}
		}
	}
	var addrs []string
	for _, w := range clients() {
		if shouldReap(w, name, action, states, pids) {
			if a := addrOf(w); a != "" {
				addrs = append(addrs, a)
			}
		}
	}
	if len(addrs) == 0 {
		return 0
	}
	killAddresses(addrs)
	return len(addrs)
}

func quitApp(name string) {
	pattern := killOf[name]
	if pattern == "" {
		return
	}
	if containerStates()[name] != "running" {
		return
	}
	_ = run([]string{"docker", "exec", name, "pkill", "-9", "-f", pattern}, 2*time.Second)
	time.Sleep(80 * time.Millisecond)
	reap(name, "stop")
}

func liveOwners() map[string]bool {
	out := map[string]bool{}
	for _, w := range liveClients() {
		if owner := classOwner(clsOf(w)); owner != "" {
			out[owner] = true
		}
	}
	return out
}

var lastSeen = map[string]time.Time{}

func quitOrphans() {
	now := time.Now()
	alive := liveOwners()
	for name := range alive {
		lastSeen[name] = now
	}
	states := containerStates()
	for name := range classOf {
		if alive[name] {
			continue
		}
		if states[name] != "running" {
			delete(lastSeen, name)
			continue
		}
		seen, ok := lastSeen[name]
		if !ok {
			continue
		}
		if now.Sub(seen) < 350*time.Millisecond {
			continue
		}
		quitApp(name)
		delete(lastSeen, name)
	}
}

func hyprSocket2() string {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = "/run/user/" + strconv.Itoa(os.Getuid())
	}
	if sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); sig != "" {
		p := filepath.Join(runtime, "hypr", sig, ".socket2.sock")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	base := filepath.Join(runtime, "hypr")
	ents, err := os.ReadDir(base)
	if err != nil {
		return ""
	}
	var newest string
	var newestT time.Time
	for _, e := range ents {
		p := filepath.Join(base, e.Name(), ".socket2.sock")
		st, err := os.Stat(p)
		if err != nil {
			continue
		}
		if newest == "" || st.ModTime().After(newestT) {
			newest, newestT = p, st.ModTime()
		}
	}
	return newest
}

func openHypr() net.Conn {
	p := hyprSocket2()
	if p == "" {
		return nil
	}
	c, err := net.DialTimeout("unix", p, 400*time.Millisecond)
	if err != nil {
		return nil
	}
	return c
}

func watch() int {
	cmd := exec.Command("docker", "events", "--filter", "type=container", "--format", "{{.Actor.Attributes.name}} {{.Action}}")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return 1
	}
	if err := cmd.Start(); err != nil {
		return 1
	}
	defer func() { _ = cmd.Process.Kill() }()

	hypr := openHypr()
	defer func() {
		if hypr != nil {
			_ = hypr.Close()
		}
	}()

	reap("", "")
	quitOrphans()
	last := time.Now()
	dockerCh := make(chan string, 8)
	go func() {
		sc := bufio.NewScanner(stdout)
		for sc.Scan() {
			dockerCh <- sc.Text()
		}
		close(dockerCh)
	}()
	hyprCh := make(chan string, 8)
	var startHyprRead func(net.Conn)
	startHyprRead = func(c net.Conn) {
		if c == nil {
			return
		}
		go func() {
			r := bufio.NewReader(c)
			for {
				line, err := r.ReadString('\n')
				if err != nil {
					hyprCh <- ""
					return
				}
				hyprCh <- strings.TrimRight(line, "\n")
			}
		}()
	}
	startHyprRead(hypr)

	tick := time.NewTicker(250 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case line, ok := <-dockerCh:
			if !ok {
				return 0
			}
			parts := strings.Fields(line)
			if len(parts) < 2 {
				continue
			}
			evName := parts[0]
			action := strings.Split(parts[1], ":")[0]
			if stopActions[action] && !skipEvents[evName] {
				reap(evName, action)
				reap(evName, action)
			}
		case ev := <-hyprCh:
			if ev == "" {
				if hypr != nil {
					_ = hypr.Close()
				}
				hypr = nil
				continue
			}
			kind, _, _ := strings.Cut(ev, ">>")
			if kind == "closewindow" || kind == "destroy" || kind == "urgent" {
				time.Sleep(150 * time.Millisecond)
				quitOrphans()
				last = time.Now()
			}
		case <-tick.C:
			if time.Since(last) >= 4*time.Second {
				reap("", "")
				quitOrphans()
				last = time.Now()
				if hypr == nil {
					hypr = openHypr()
					startHyprRead(hypr)
				}
			}
		}
	}
}

func Main(args []string) {
	if len(args) == 1 && args[0] == "watch" {
		os.Exit(watch())
	}
	if len(args) == 1 && args[0] == "quit-orphans" {
		quitOrphans()
		return
	}
	name, action := "", "stop"
	if len(args) > 0 {
		name = args[0]
	}
	if len(args) > 1 {
		action = args[1]
	}
	if action == "quit" {
		quitApp(name)
		return
	}
	reap(name, action)
}
