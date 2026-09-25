package activate

import (
	"encoding/json"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

var weak = map[string]bool{
	"a": true, "app": true, "applicationstatus": true, "ayatana": true, "bin": true,
	"chrome": true, "chromium": true, "com": true, "config": true, "dark": true,
	"desktop": true, "disable": true, "enable": true, "features": true, "force": true,
	"freedesktop": true, "gnome": true, "google": true, "gpu": true, "gtk": true,
	"home": true, "icon": true, "indicator": true, "io": true, "item": true,
	"kde": true, "mode": true, "net": true, "nix": true, "notification": true,
	"notificationitem": true, "notifier": true, "org": true, "ozone": true,
	"platform": true, "qt": true, "sandbox": true, "scripts": true, "status": true,
	"statusnotifieritem": true, "store": true, "tray": true, "usr": true,
	"wayland": true, "www": true,
}

var genericSNI = []string{"chrome_status_icon", "status_icon"}
var wrapRE = regexp.MustCompile(`(-wrapped|-wrappe|wrapped|wrappe)$`)
var extRE = regexp.MustCompile(`\.(desktop|sh)$`)

func init() {
	if h := os.Getenv("HOME"); h != "" {
		weak[strings.ToLower(filepathBase(h))] = true
	}
}

func filepathBase(p string) string {
	i := strings.LastIndex(p, "/")
	if i < 0 {
		return p
	}
	return p[i+1:]
}

func stripWrap(s string) string {
	t := strings.ToLower(strings.TrimLeft(s, "."))
	t = extRE.ReplaceAllString(t, "")
	t = wrapRE.ReplaceAllString(t, "")
	return t
}

func isDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return s != ""
}

func chromeKind(s string) string {
	c := stripWrap(s)
	if c == "chrome-az" || strings.HasPrefix(c, "chrome-az") {
		return "az"
	}
	if c == "chrome-hika" || strings.HasPrefix(c, "chrome-hika") {
		return "hika"
	}
	if c == "chrome-dd" || strings.HasPrefix(c, "chrome-dd") || c == "google-chrome" || c == "com.google.chrome" {
		return "dd"
	}
	return ""
}

func tokenHit(needle, hay string) bool {
	n, h := stripWrap(needle), stripWrap(hay)
	if n == "" || h == "" || weak[n] || len(n) < 3 {
		return false
	}
	ck, hk := chromeKind(n), chromeKind(h)
	if ck != "" || hk != "" {
		return ck != "" && ck == hk
	}
	if n == h {
		return true
	}
	if len(n) >= 4 && (strings.HasPrefix(h, n) || (strings.HasPrefix(n, h) && len(h) >= 4)) {
		return true
	}
	if len(n) >= 5 && strings.Contains(h, n) {
		return true
	}
	return false
}

func anyHit(needles map[string]bool, hays ...string) bool {
	for n := range needles {
		for _, h := range hays {
			if tokenHit(n, h) {
				return true
			}
		}
	}
	return false
}

func busOwners() map[string][2]string {
	_, out := execx.Run(400*time.Millisecond, "busctl", "--user", "list")
	owners := map[string][2]string{}
	for _, line := range strings.Split(out, "\n") {
		parts := strings.Fields(line)
		if len(parts) < 3 {
			continue
		}
		owners[parts[0]] = [2]string{parts[1], strings.ToLower(parts[2])}
	}
	return owners
}

func sniItems() [][2]string {
	_, out := execx.Run(400*time.Millisecond, "busctl", "--user", "get-property",
		"org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
		"org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
	var items [][2]string
	for _, raw := range quoted(out) {
		spec := raw
		if !strings.HasPrefix(spec, ":") && !strings.Contains(spec, ".") {
			spec = ":" + spec
		}
		if !strings.Contains(spec, "/") {
			continue
		}
		dest, path, _ := strings.Cut(spec, "/")
		items = append(items, [2]string{dest, "/" + path})
	}
	return items
}

func quoted(s string) []string {
	var out []string
	in := false
	var b strings.Builder
	for _, r := range s {
		if r == '"' {
			if in {
				out = append(out, b.String())
				b.Reset()
				in = false
			} else {
				in = true
			}
			continue
		}
		if in {
			b.WriteRune(r)
		}
	}
	return out
}

func sniProp(dest, path, prop string) string {
	for _, iface := range []string{"org.kde.StatusNotifierItem", "org.freedesktop.StatusNotifierItem"} {
		code, out := execx.Run(400*time.Millisecond, "busctl", "--user", "get-property", dest, path, iface, prop)
		if code != 0 {
			continue
		}
		text := strings.TrimSpace(out)
		if strings.HasPrefix(text, "s ") {
			text = strings.Trim(strings.TrimSpace(text[2:]), `"`)
		}
		if text != "" {
			return text
		}
	}
	return ""
}

func sniActivate(dest, path string) bool {
	for _, iface := range []string{"org.kde.StatusNotifierItem", "org.freedesktop.StatusNotifierItem"} {
		if execx.RunOK(400*time.Millisecond, "busctl", "--user", "call", dest, path, iface, "Activate", "ii", "0", "0") {
			return true
		}
	}
	return false
}

func mprisRaise(needles map[string]bool, owners map[string][2]string, probe bool) bool {
	for name, info := range owners {
		if !strings.HasPrefix(name, "org.mpris.MediaPlayer2.") {
			continue
		}
		pid, comm := info[0], info[1]
		if pid == "-" || pid == "" || !isDigits(pid) {
			continue
		}
		tail := name[strings.LastIndex(name, ".")+1:]
		if strings.HasPrefix(tail, "chromium") || strings.HasPrefix(tail, "instance") {
			continue
		}
		if !anyHit(needles, tail, comm, name) {
			continue
		}
		if probe {
			return true
		}
		if execx.RunOK(400*time.Millisecond, "busctl", "--user", "call", name, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2", "Raise") {
			return true
		}
	}
	return false
}

func dbusAppActivate(needles map[string]bool, owners map[string][2]string, probe bool) bool {
	for name, info := range owners {
		if strings.HasPrefix(name, ":") {
			continue
		}
		pid, comm := info[0], info[1]
		if pid == "-" || pid == "" || !isDigits(pid) {
			continue
		}
		low := strings.ToLower(name)
		if strings.HasPrefix(low, "org.mpris.") || strings.HasPrefix(low, "org.freedesktop.") || strings.HasPrefix(low, "org.kde.") {
			continue
		}
		tail := name
		if i := strings.LastIndex(name, "."); i >= 0 {
			tail = name[i+1:]
		}
		if !anyHit(needles, name, tail, comm) {
			continue
		}
		if probe {
			return true
		}
		path := "/" + strings.ReplaceAll(name, ".", "/")
		if execx.RunOK(400*time.Millisecond, "busctl", "--user", "call", name, path, "org.freedesktop.Application", "Activate", "a{sv}", "0") {
			return true
		}
	}
	return false
}

func processRunning(needles map[string]bool) bool {
	_, out := execx.Run(400*time.Millisecond, "ps", "-u", strconv.Itoa(os.Getuid()), "-o", "comm=")
	skip := map[string]bool{"chrome crashpad": true, "crashpad": true, "zygote": true, "bwrap": true, "xdg-dbus-proxy": true}
	for _, line := range strings.Split(out, "\n") {
		comm := stripWrap(strings.TrimSpace(line))
		if comm == "" || skip[comm] {
			continue
		}
		if anyHit(needles, comm) {
			return true
		}
	}
	return false
}

func boundedHit(hay, needle string) bool {
	h, n := strings.ToLower(hay), strings.ToLower(needle)
	if h == "" || n == "" || weak[n] {
		return false
	}
	if h == n {
		return true
	}
	from := 0
	for from <= len(h) {
		idx := strings.Index(h[from:], n)
		if idx < 0 {
			return false
		}
		idx += from
		var before, after byte
		if idx > 0 {
			before = h[idx-1]
		}
		if idx+len(n) < len(h) {
			after = h[idx+len(n)]
		}
		edgeL := before == 0 || !alnum(before)
		edgeR := after == 0 || !alnum(after)
		if edgeL && edgeR {
			return true
		}
		from = idx + 1
	}
	return false
}

func alnum(b byte) bool {
	return (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9')
}

func classHit(cls, needle string) bool {
	c, n := stripWrap(cls), stripWrap(needle)
	if c == "" || n == "" || weak[n] || len(n) < 3 {
		return false
	}
	ck, nk := chromeKind(c), chromeKind(n)
	if ck != "" || nk != "" {
		return ck != "" && ck == nk
	}
	if c == n || boundedHit(c, n) {
		return true
	}
	if len(n) >= 4 && len(c) >= 4 && boundedHit(n, c) {
		return true
	}
	cLast := lastTok(c)
	nLast := lastTok(n)
	return len(cLast) >= 3 && len(nLast) >= 3 && cLast == nLast
}

func lastTok(s string) string {
	s = strings.ReplaceAll(s, "_", "-")
	s = strings.ReplaceAll(s, ".", "-")
	parts := strings.Split(s, "-")
	return parts[len(parts)-1]
}

type win struct {
	Mapped       *bool   `json:"mapped"`
	Hidden       *bool   `json:"hidden"`
	Size         []int   `json:"size"`
	Class        string  `json:"class"`
	InitialClass string  `json:"initialClass"`
	Title        string  `json:"title"`
	Address      string  `json:"address"`
}

func hyprClients() []win {
	_, raw := execx.Run(600*time.Millisecond, "hyprctl", "-j", "clients")
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var data []win
	if json.Unmarshal([]byte(raw), &data) != nil {
		return nil
	}
	return data
}

func hyprFocus(needles map[string]bool, probe bool) bool {
	bestAddr := ""
	bestArea := -1
	for _, c := range hyprClients() {
		cls := strings.ToLower(c.Class)
		if cls == "" {
			cls = strings.ToLower(c.InitialClass)
		}
		title := strings.ToLower(c.Title)
		if cls == "" || strings.Contains(cls, "quickshell") || strings.Contains(cls, "aurora-") || strings.Contains(cls, "hyprland") {
			continue
		}
		if c.Hidden != nil && *c.Hidden {
			continue
		}
		hit := false
		for n := range needles {
			if classHit(cls, n) || (len(n) >= 5 && boundedHit(title, n)) {
				hit = true
				break
			}
		}
		if !hit {
			continue
		}
		area := 0
		if len(c.Size) >= 2 {
			area = c.Size[0] * c.Size[1]
		}
		addr := c.Address
		if addr == "" {
			continue
		}
		if area < 40000 && bestArea >= 40000 {
			continue
		}
		if area >= bestArea {
			bestArea = area
			if !strings.HasPrefix(addr, "0x") {
				addr = "0x" + addr
			}
			bestAddr = addr
		}
	}
	if bestAddr == "" {
		return false
	}
	if probe {
		return true
	}
	lua := `(function() local w = hl.get_window("address:` + bestAddr + `"); if not w then return false end; hl.dispatch(hl.dsp.focus({ window = w })); return true end)()`
	code, out := execx.Run(600*time.Millisecond, "hyprctl", "eval", lua)
	text := strings.ToLower(out)
	if code == 0 && !strings.Contains(text, "false") && !strings.Contains(text, "not found") {
		return true
	}
	return execx.RunOK(400*time.Millisecond, "hyprctl", "dispatch", "focuswindow", "address:"+bestAddr)
}

func Main(args []string) int {
	probe := false
	var needlesArgs []string
	for _, a := range args {
		if a == "--probe" {
			probe = true
			continue
		}
		needlesArgs = append(needlesArgs, a)
	}
	needles := map[string]bool{}
	for _, a := range needlesArgs {
		t := stripWrap(a)
		if t != "" && !weak[t] {
			needles[t] = true
		}
	}
	if len(needles) == 0 {
		return 1
	}
	if hyprFocus(needles, probe) {
		return 0
	}
	owners := busOwners()
	electron := needles["cursor"] || needles["code"] || needles["code-oss"] || needles["codium"] || needles["obsidian"]
	for _, item := range sniItems() {
		dest, path := item[0], item[1]
		sid := sniProp(dest, path, "Id")
		title := sniProp(dest, path, "Title")
		icon := sniProp(dest, path, "IconName")
		comm := ""
		if o, ok := owners[dest]; ok {
			comm = o[1]
		}
		blob := strings.ToLower(sid + " " + title + " " + icon)
		generic := false
		for _, g := range genericSNI {
			if strings.Contains(blob, g) {
				generic = true
			}
		}
		if generic && title == "" {
			if comm != "" && anyHit(needles, comm) {
				if probe || sniActivate(dest, path) {
					if electron {
						return 2
					}
					return 0
				}
			}
			continue
		}
		if anyHit(needles, sid, title, icon, comm) {
			if probe || sniActivate(dest, path) {
				if electron {
					return 2
				}
				return 0
			}
		}
	}
	if mprisRaise(needles, owners, probe) {
		return 0
	}
	if dbusAppActivate(needles, owners, probe) {
		return 0
	}
	if processRunning(needles) {
		return 2
	}
	return 1
}
