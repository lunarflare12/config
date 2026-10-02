package brightness

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

const (
	hyprMin = 10
	hyprMax = 100
	ddcMin  = 0
	ddcMax  = 100
)

var (
	displayLine = regexp.MustCompile(`(?i)Display\s+\d+`)
	invalidLine = regexp.MustCompile(`(?i)Invalid display`)
	i2cBus      = regexp.MustCompile(`(?i)i2c-(\d+)`)
	drmConn     = regexp.MustCompile(`(?i)(?:DRM connector|DRM_connector):\s*(?:card\d+-)?(.+)`)
	vcpLine     = regexp.MustCompile(`VCP\s+10\s+\S+\s+(\d+)\s+(\d+)`)
	specRel     = regexp.MustCompile(`^[+-]\d+%?$`)
	skipI2C     = regexp.MustCompile(`(?i)SMBus|DesignWare|aux hw`)
	i2cDev      = regexp.MustCompile(`/dev/i2c-(\d+)`)
)

type displayEntry struct {
	Name     string `json:"name"`
	Label    string `json:"label"`
	Backend  string `json:"backend"`
	Percent  int    `json:"percent"`
	Max      int    `json:"max"`
	Selected bool   `json:"selected"`
	Bus      int    `json:"bus,omitempty"`
}

type stateData struct {
	Selected   string                    `json:"selected"`
	Gamma      int                       `json:"gamma"`
	Displays   map[string]map[string]any `json:"displays"`
	DDC        map[string]map[string]any `json:"ddc"`
	Updated    int64                     `json:"updated"`
	DDCSkip    []any                     `json:"ddc_skip"`
	DDCChecked int64                     `json:"ddc_checked"`
}

func stateDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return d
	}
	return filepath.Join(execx.Home(), ".local", "state")
}

func statePath() string {
	return filepath.Join(stateDir(), "aurora", "brightness.json")
}

func lockPath() string {
	return filepath.Join(stateDir(), "aurora", "ddcutil.lock")
}

func legacyPath() string {
	return filepath.Join(stateDir(), "monitor-brightness")
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func runCmd(timeout time.Duration, name string, args ...string) string {
	code, out, errOut := execx.RunFull(timeout, name, args...)
	text := out
	if text == "" {
		text = errOut
	}
	if code != 0 && text == "" {
		return ""
	}
	return text
}

func loadState() stateData {
	data := stateData{
		Gamma:    100,
		Displays: map[string]map[string]any{},
		DDC:      map[string]map[string]any{},
	}
	_ = os.MkdirAll(filepath.Dir(statePath()), 0o755)
	if b, err := os.ReadFile(statePath()); err == nil {
		var parsed stateData
		if json.Unmarshal(b, &parsed) == nil {
			if parsed.Displays == nil {
				parsed.Displays = map[string]map[string]any{}
			}
			if parsed.DDC == nil {
				parsed.DDC = map[string]map[string]any{}
			}
			return parsed
		}
	}
	if b, err := os.ReadFile(legacyPath()); err == nil {
		digits := regexp.MustCompile(`[^0-9]`).ReplaceAllString(strings.TrimSpace(string(b)), "")
		if digits != "" {
			if n, err := strconv.Atoi(digits); err == nil {
				data.Gamma = clamp(n, hyprMin, hyprMax)
			}
		}
	}
	return data
}

func saveState(data *stateData) {
	_ = os.MkdirAll(filepath.Dir(statePath()), 0o755)
	data.Updated = time.Now().Unix()
	tmp := statePath() + ".tmp"
	b, _ := json.Marshal(data)
	_ = os.WriteFile(tmp, append(b, '\n'), 0o644)
	_ = os.Rename(tmp, statePath())
	_ = os.WriteFile(legacyPath(), []byte(strconv.Itoa(data.Gamma)+"\n"), 0o644)
}

func i2cName(bus int) string {
	b, err := os.ReadFile(fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/name", bus))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func skipBuses(state *stateData) []int {
	skip := map[int]bool{}
	for _, raw := range state.DDCSkip {
		switch t := raw.(type) {
		case float64:
			skip[int(t)] = true
		case int:
			skip[t] = true
		case string:
			if n, err := strconv.Atoi(t); err == nil {
				skip[n] = true
			}
		}
	}
	ents, err := os.ReadDir("/sys/bus/i2c/devices")
	if err == nil {
		for _, ent := range ents {
			if !strings.HasPrefix(ent.Name(), "i2c-") {
				continue
			}
			bus, err := strconv.Atoi(strings.TrimPrefix(ent.Name(), "i2c-"))
			if err != nil {
				continue
			}
			if skipI2C.MatchString(i2cName(bus)) {
				skip[bus] = true
			}
		}
	}
	out := make([]int, 0, len(skip))
	for b := range skip {
		out = append(out, b)
	}
	sort.Ints(out)
	return out
}

func rememberSkip(state *stateData, buses []int, extra string) {
	skip := map[int]bool{}
	for _, b := range skipBuses(state) {
		skip[b] = true
	}
	for _, b := range buses {
		skip[b] = true
	}
	for _, m := range i2cDev.FindAllStringSubmatch(extra, -1) {
		if len(m) > 1 {
			if n, err := strconv.Atoi(m[1]); err == nil {
				skip[n] = true
			}
		}
	}
	state.DDCSkip = make([]any, 0, len(skip))
	for b := range skip {
		state.DDCSkip = append(state.DDCSkip, b)
	}
	sort.Slice(state.DDCSkip, func(i, j int) bool {
		return fmt.Sprint(state.DDCSkip[i]) < fmt.Sprint(state.DDCSkip[j])
	})
}

func ddcutilCmd(args []string, state *stateData) []string {
	cmd := []string{"ddcutil", "--noconfig", "--disable-flock"}
	for _, bus := range skipBuses(state) {
		cmd = append(cmd, "--ignore-bus", strconv.Itoa(bus))
	}
	return append(cmd, args...)
}

func ddcutilRun(args []string, timeout time.Duration, state *stateData) string {
	_ = os.MkdirAll(filepath.Dir(lockPath()), 0o755)
	fh, err := os.OpenFile(lockPath(), os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return runCmd(timeout, "ddcutil", args...)
	}
	defer fh.Close()
	_ = syscall.Flock(int(fh.Fd()), syscall.LOCK_EX)
	defer syscall.Flock(int(fh.Fd()), syscall.LOCK_UN)
	cmd := ddcutilCmd(args, state)
	return runCmd(timeout, cmd[0], cmd[1:]...)
}

type hyprMon struct {
	Name, Description string
	Focused           bool
	X                 int
}

func hyprMonitors() []hyprMon {
	text := strings.TrimSpace(runCmd(2*time.Second, "hyprctl", "monitors", "-j"))
	if text == "" {
		return nil
	}
	var payload []map[string]any
	if json.Unmarshal([]byte(text), &payload) != nil {
		return nil
	}
	var out []hyprMon
	for _, item := range payload {
		name := strings.TrimSpace(fmt.Sprint(item["name"]))
		if name == "" {
			continue
		}
		out = append(out, hyprMon{
			Name:        name,
			Description: strings.TrimSpace(fmt.Sprint(item["description"])),
			Focused:     item["focused"] == true,
			X:           intFromAny(item["x"]),
		})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].X != out[j].X {
			return out[i].X < out[j].X
		}
		return out[i].Name < out[j].Name
	})
	return out
}

func intFromAny(v any) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	default:
		return 0
	}
}

func readGamma() *int {
	text := runCmd(2*time.Second, "hyprctl", "hyprsunset", "gamma")
	lines := strings.Split(text, "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		digits := regexp.MustCompile(`[^0-9+-]`).ReplaceAllString(strings.TrimSpace(lines[i]), "")
		if digits == "" {
			continue
		}
		if n, err := strconv.Atoi(digits); err == nil {
			v := clamp(n, 0, 200)
			return &v
		}
	}
	return nil
}

func friendlyLabel(name, description string) string {
	if description == "" {
		return name
	}
	tokens := strings.Fields(description)
	skip := map[string]bool{"corporation": true, "company": true, "consumer": true, "electronics": true, "inc": true, "ltd": true, "inc.": true, "ltd.": true}
	if len(tokens) > 0 {
		last := tokens[len(tokens)-1]
		digits := 0
		for _, c := range last {
			if c >= '0' && c <= '9' {
				digits++
			}
		}
		if digits >= 6 {
			tokens = tokens[:len(tokens)-1]
		}
	}
	var kept []string
	for _, tok := range tokens {
		if !skip[strings.ToLower(tok)] {
			kept = append(kept, tok)
		}
	}
	if len(kept) == 0 {
		return name
	}
	return strings.Join(kept, " ")
}

func parseDDCDetect(text string) (map[string]int, []int) {
	mapping := map[string]int{}
	var invalid []int
	var bus *int
	var connector string
	valid := false
	commit := func() {
		if valid && connector != "" && bus != nil {
			mapping[connector] = *bus
		} else if bus != nil {
			invalid = append(invalid, *bus)
		}
	}
	for _, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		if invalidLine.MatchString(line) || displayLine.MatchString(line) {
			commit()
			bus = nil
			connector = ""
			valid = displayLine.MatchString(line) && !invalidLine.MatchString(line)
			continue
		}
		if m := i2cBus.FindStringSubmatch(line); len(m) > 1 {
			if n, err := strconv.Atoi(m[1]); err == nil {
				bus = &n
			}
		}
		if m := drmConn.FindStringSubmatch(line); len(m) > 1 {
			connector = strings.TrimSpace(m[1])
		}
	}
	commit()
	return mapping, invalid
}

func readDDC(bus int, state *stateData) *int {
	text := ddcutilRun([]string{"--bus", strconv.Itoa(bus), "--brief", "--sleep-multiplier", ".2", "getvcp", "10"}, 5*time.Second, state)
	m := vcpLine.FindStringSubmatch(text)
	if m == nil {
		return nil
	}
	cur, _ := strconv.Atoi(m[1])
	maximum, _ := strconv.Atoi(m[2])
	if maximum == 0 {
		maximum = 100
	}
	v := clamp(int(float64(cur)*100/float64(maximum)+0.5), ddcMin, ddcMax)
	return &v
}

func setDDC(bus, percent int, state *stateData) {
	value := clamp(percent, ddcMin, ddcMax)
	_ = ddcutilRun([]string{
		"--bus", strconv.Itoa(bus), "--noverify", "--permit-unknown-feature",
		"--sleep-multiplier", ".2", "setvcp", "10", strconv.Itoa(value),
	}, 5*time.Second, state)
}

func discoverDDC(state *stateData, force bool) *stateData {
	checked := state.DDCChecked
	cached := state.DDC
	if !force && len(cached) > 0 && time.Now().Unix()-checked < 3600 {
		return state
	}
	text := ddcutilRun([]string{"detect", "--brief", "--sleep-multiplier", ".15"}, 8*time.Second, state)
	mapping, invalid := parseDDCDetect(text)
	rememberSkip(state, invalid, "")
	ddc := map[string]map[string]any{}
	for name, bus := range mapping {
		current := readDDC(bus, state)
		if current == nil {
			rememberSkip(state, []int{bus}, "")
			continue
		}
		ddc[name] = map[string]any{"bus": bus}
		entry := state.Displays[name]
		if entry == nil {
			entry = map[string]any{}
		}
		entry["percent"] = *current
		entry["backend"] = "ddc"
		state.Displays[name] = entry
	}
	state.DDC = ddc
	state.DDCChecked = time.Now().Unix()
	return state
}

func backendFor(name string, state *stateData) (string, int) {
	info := state.DDC[name]
	if info != nil && info["bus"] != nil {
		return "ddc", intFromAny(info["bus"])
	}
	return "gamma", 0
}

func limitsFor(backend string) (int, int) {
	if backend == "gamma" {
		return hyprMin, hyprMax
	}
	return ddcMin, ddcMax
}

func parseSpec(spec string, current, lo, hi int) int {
	text := strings.TrimSpace(spec)
	if specRel.MatchString(text) {
		delta, _ := strconv.Atoi(strings.TrimSuffix(text, "%"))
		return clamp(current+delta, lo, hi)
	}
	if strings.HasSuffix(text, "%+") {
		n, _ := strconv.Atoi(strings.TrimSuffix(text, "%+"))
		return clamp(current+n, lo, hi)
	}
	if strings.HasSuffix(text, "%-") {
		n, _ := strconv.Atoi(strings.TrimSuffix(text, "%-"))
		return clamp(current-n, lo, hi)
	}
	if strings.HasSuffix(text, "%") {
		n, _ := strconv.Atoi(strings.TrimSuffix(text, "%"))
		return clamp(n, lo, hi)
	}
	n, _ := strconv.Atoi(text)
	return clamp(n, lo, hi)
}

func percentOf(name, backend string, state *stateData) int {
	lo, hi := limitsFor(backend)
	if entry := state.Displays[name]; entry != nil {
		if stored := entry["percent"]; stored != nil {
			return clamp(intFromAny(stored), lo, hi)
		}
	}
	if backend == "gamma" && state.Gamma != 0 {
		return clamp(state.Gamma, lo, hi)
	}
	return 100
}

func snapshot(state *stateData, monitors []hyprMon) map[string]any {
	if monitors == nil {
		monitors = hyprMonitors()
	}
	if g := readGamma(); g != nil {
		state.Gamma = clamp(*g, hyprMin, hyprMax)
	}
	names := make([]string, len(monitors))
	for i, m := range monitors {
		names[i] = m.Name
	}
	selected := state.Selected
	focused := ""
	for _, m := range monitors {
		if m.Focused {
			focused = m.Name
			break
		}
	}
	found := false
	for _, n := range names {
		if n == selected {
			found = true
			break
		}
	}
	if !found {
		if focused != "" {
			selected = focused
		} else if len(names) > 0 {
			selected = names[0]
		} else {
			selected = ""
		}
	}
	state.Selected = selected
	var displays []displayEntry
	for _, mon := range monitors {
		backend, bus := backendFor(mon.Name, state)
		percent := percentOf(mon.Name, backend, state)
		entry := displayEntry{
			Name: mon.Name, Label: friendlyLabel(mon.Name, mon.Description),
			Backend: backend, Percent: percent, Max: 100, Selected: mon.Name == selected,
		}
		if bus != 0 || backend == "ddc" {
			entry.Bus = bus
		}
		displays = append(displays, entry)
		st := state.Displays[mon.Name]
		if st == nil {
			st = map[string]any{}
		}
		st["percent"] = percent
		st["backend"] = backend
		state.Displays[mon.Name] = st
	}
	selectedRow := displayEntry{Name: "", Percent: 100}
	if len(displays) > 0 {
		selectedRow = displays[0]
		for _, row := range displays {
			if row.Selected {
				selectedRow = row
				break
			}
		}
		anySel := false
		for _, row := range displays {
			if row.Selected {
				anySel = true
				break
			}
		}
		if !anySel {
			displays[0].Selected = true
			selectedRow = displays[0]
			state.Selected = selectedRow.Name
		}
	}
	return map[string]any{
		"selected": selectedRow.Name,
		"gamma":    state.Gamma,
		"displays": displays,
	}
}

func applyPercent(state *stateData, name string, percent int, persist bool) map[string]any {
	monitors := hyprMonitors()
	names := make([]string, len(monitors))
	for i, m := range monitors {
		names[i] = m.Name
	}
	if name == "" {
		name = state.Selected
	}
	found := false
	for _, n := range names {
		if n == name {
			found = true
			break
		}
	}
	if !found && len(names) > 0 {
		name = names[0]
	}
	backend, bus := backendFor(name, state)
	if backend != "ddc" || bus == 0 {
		if len(state.DDC) == 0 {
			discoverDDC(state, false)
			backend, bus = backendFor(name, state)
		}
	}
	lo, hi := limitsFor("gamma")
	value := clamp(percent, lo, hi)
	st := state.Displays[name]
	if st == nil {
		st = map[string]any{}
	}
	if backend == "ddc" && bus != 0 {
		setDDC(bus, value, state)
		st["percent"] = value
		st["backend"] = "ddc"
	} else {
		st["percent"] = value
		st["backend"] = "gamma"
	}
	state.Displays[name] = st
	state.Selected = name
	if persist {
		saveState(state)
	}
	return snapshot(state, monitors)
}

func applyAll(state *stateData, spec string) map[string]any {
	payload := snapshot(state, nil)
	list, _ := payload["displays"].([]displayEntry)
	if len(list) == 0 {
		return payload
	}
	base := list[0].Percent
	nxt := parseSpec(spec, base, 0, 100)
	for _, row := range list {
		applyPercent(state, row.Name, nxt, false)
	}
	saveState(state)
	return snapshot(state, hyprMonitors())
}

func selectDisplay(state *stateData, name string) map[string]any {
	state.Selected = name
	saveState(state)
	return snapshot(state, nil)
}

type cliOpts struct {
	machine, jsonOut, discover        bool
	action, device, selectName, value string
}

func parseArgs(argv []string) cliOpts {
	var o cliOpts
	for i := 0; i < len(argv); i++ {
		arg := argv[i]
		switch arg {
		case "-m", "--machine":
			o.machine = true
		case "--json":
			o.jsonOut = true
		case "--discover":
			o.discover = true
		case "-d", "--device":
			if i+1 < len(argv) {
				i++
				o.device = argv[i]
			}
		case "--select":
			if i+1 < len(argv) {
				i++
				o.selectName = argv[i]
			}
		case "set", "info", "-l", "--list":
			o.action = arg
		default:
			if !strings.HasPrefix(arg, "-") {
				o.value = arg
			}
		}
	}
	return o
}

func emitJSON(payload map[string]any) {
	b, _ := json.Marshal(payload)
	_, _ = os.Stdout.Write(b)
	_, _ = os.Stdout.Write([]byte("\n"))
}

func emitMachine(payload map[string]any) {
	selected := fmt.Sprint(payload["selected"])
	list, _ := payload["displays"].([]displayEntry)
	var row displayEntry
	for _, item := range list {
		if item.Name == selected {
			row = item
			break
		}
	}
	if row.Name == "" && len(list) > 0 {
		row = list[0]
	}
	fmt.Printf("%s,%s,%d,%d%%,%d\n", row.Name, row.Backend, row.Percent, row.Percent, row.Max)
}

func Main(args []string) int {
	opts := parseArgs(args)
	state := loadState()
	if opts.discover {
		discoverDDC(&state, true)
		saveState(&state)
	}
	var payload map[string]any
	switch {
	case opts.selectName != "":
		payload = selectDisplay(&state, opts.selectName)
	case opts.action == "set":
		spec := opts.value
		if spec == "" {
			spec = "100%"
		}
		if opts.device != "" {
			payload = snapshot(&state, nil)
			list, _ := payload["displays"].([]displayEntry)
			target := opts.device
			row := displayEntry{}
			for _, item := range list {
				if item.Name == target {
					row = item
					break
				}
			}
			if row.Name == "" && len(list) > 0 {
				row = list[0]
			}
			lo, hi := limitsFor(row.Backend)
			nxt := parseSpec(spec, row.Percent, lo, hi)
			payload = applyPercent(&state, row.Name, nxt, true)
		} else {
			payload = applyAll(&state, spec)
		}
	default:
		payload = snapshot(&state, nil)
	}
	if opts.jsonOut {
		emitJSON(payload)
		return 0
	}
	if opts.machine {
		emitMachine(payload)
		return 0
	}
	list, _ := payload["displays"].([]displayEntry)
	for _, row := range list {
		mark := " "
		if row.Selected {
			mark = "*"
		}
		kind := "software"
		if row.Backend == "ddc" {
			kind = "hardware"
		}
		fmt.Printf("%s %-10s %3d%%  %s  %s\n", mark, row.Name, row.Percent, kind, row.Label)
	}
	return 0
}
