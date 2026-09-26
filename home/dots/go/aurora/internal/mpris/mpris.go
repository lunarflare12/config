package mpris

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

var media = []string{"chrome-dd", "chrome-az", "chrome-hika", "firefox", "zen", "spotify"}

var skipMPRIS = map[string]bool{
	"steam": true, "overwatch": true, "terraria": true, "albion": true,
	"ollama": true, "omniroute": true, "vscode": true, "idea": true,
	"obsidian": true, "openlens": true, "libreoffice": true,
	"telegram-1": true, "telegram-2": true,
}

const bus = "unix:path=/tmp/xdg/bus"

type snap struct {
	Available    bool    `json:"available"`
	Playing      bool    `json:"playing"`
	Source       string  `json:"source"`
	Container    string  `json:"container"`
	Name         string  `json:"name"`
	Title        string  `json:"title"`
	Artist       string  `json:"artist"`
	Album        string  `json:"album"`
	Identity     string  `json:"identity"`
	DesktopEntry string  `json:"desktopEntry"`
	ArtURL       string  `json:"artUrl"`
	TrackID      string  `json:"trackId"`
	Length       float64 `json:"length"`
	Position     float64 `json:"position"`
	CanToggle    bool    `json:"canToggle"`
	CanNext      bool    `json:"canNext"`
	CanPrevious  bool    `json:"canPrevious"`
	CanSeek      bool    `json:"canSeek"`
	CanRaise     bool    `json:"canRaise"`
}

func runtimeDir() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	return "/run/user/" + strconv.Itoa(os.Getuid())
}

func stateDir() string { return filepath.Join(runtimeDir(), "aurora-mpris") }
func statePath() string { return filepath.Join(stateDir(), "active.json") }
func artPath() string   { return filepath.Join(stateDir(), "cover") }

func run(args []string, timeout time.Duration) (int, string) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Stderr = io.Discard
	out, err := cmd.Output()
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return ee.ExitCode(), strings.TrimSpace(string(out))
		}
		return 1, ""
	}
	return 0, strings.TrimSpace(string(out))
}

func runningMedia() []string {
	code, out := run([]string{"docker", "ps", "--format", "{{.Names}}"}, 4*time.Second)
	if code != 0 || out == "" {
		return nil
	}
	have := map[string]bool{}
	for _, line := range strings.Split(out, "\n") {
		n := strings.TrimSpace(line)
		if n != "" {
			have[n] = true
		}
	}
	var names []string
	for _, n := range media {
		if have[n] {
			names = append(names, n)
		}
	}
	for n := range have {
		if skipMPRIS[n] || strings.HasPrefix(n, "steam_") {
			continue
		}
		dup := false
		for _, k := range names {
			if k == n {
				dup = true
				break
			}
		}
		if !dup {
			names = append(names, n)
		}
	}
	return names
}

func busctl(container string, args []string) (int, string) {
	cmd := []string{"docker", "exec", "-e", "DBUS_SESSION_BUS_ADDRESS=" + bus, container, "busctl", "--user", "--json=short"}
	return run(append(cmd, args...), 4*time.Second)
}

type wrap struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

func unwrap(raw json.RawMessage) any {
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil
	}
	var w wrap
	if json.Unmarshal(raw, &w) == nil && w.Type != "" && len(w.Data) > 0 {
		return unwrap(w.Data)
	}
	var obj map[string]json.RawMessage
	if json.Unmarshal(raw, &obj) == nil && len(obj) > 0 {
		if _, hasType := obj["type"]; hasType {
			if data, ok := obj["data"]; ok && len(obj) <= 3 {
				return unwrap(data)
			}
		}
		out := make(map[string]any, len(obj))
		for k, v := range obj {
			out[k] = unwrap(v)
		}
		return out
	}
	var arr []json.RawMessage
	if json.Unmarshal(raw, &arr) == nil {
		out := make([]any, len(arr))
		for i, v := range arr {
			out[i] = unwrap(v)
		}
		return out
	}
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s
	}
	var f float64
	if json.Unmarshal(raw, &f) == nil {
		return f
	}
	var b bool
	if json.Unmarshal(raw, &b) == nil {
		return b
	}
	return nil
}

func parseJSON(text string) any {
	if text == "" {
		return nil
	}
	return unwrap(json.RawMessage(text))
}

func asMap(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	if list, ok := v.([]any); ok {
		for _, item := range list {
			if m, ok := item.(map[string]any); ok && len(m) > 0 {
				return m
			}
		}
	}
	return map[string]any{}
}

func firstText(v any) string {
	switch t := v.(type) {
	case []any:
		if len(t) == 0 {
			return ""
		}
		return firstText(t[0])
	case string:
		return t
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case bool:
		if t {
			return "true"
		}
		return "false"
	default:
		if t == nil {
			return ""
		}
		return ""
	}
}

func asBool(v any) bool {
	switch t := v.(type) {
	case bool:
		return t
	case string:
		return strings.EqualFold(t, "true") || t == "1"
	case float64:
		return t != 0
	default:
		return false
	}
}

func toSeconds(v any) float64 {
	var n float64
	switch t := v.(type) {
	case float64:
		n = t
	case string:
		f, err := strconv.ParseFloat(t, 64)
		if err != nil {
			return 0
		}
		n = f
	default:
		return 0
	}
	if n <= 0 {
		return 0
	}
	if n > 10000 {
		return n / 1_000_000
	}
	return n
}

var namesCache = map[string]struct {
	at    time.Time
	names []string
}{}

func mprisNames(container string) []string {
	if hit, ok := namesCache[container]; ok && time.Since(hit.at) < 4*time.Second {
		return hit.names
	}
	code, out := busctl(container, []string{"list"})
	if code != 0 || out == "" {
		return nil
	}
	var names []string
	parsed := parseJSON(out)
	if list, ok := parsed.([]any); ok {
		for _, row := range list {
			name := ""
			if m, ok := row.(map[string]any); ok {
				name = firstText(m["name"])
				if name == "" {
					name = firstText(m["NAME"])
				}
			} else {
				name = firstText(row)
			}
			if strings.HasPrefix(name, "org.mpris.MediaPlayer2.") {
				names = append(names, name)
			}
		}
	}
	if len(names) == 0 {
		for _, line := range strings.Split(out, "\n") {
			fields := strings.Fields(line)
			if len(fields) > 0 && strings.HasPrefix(fields[0], "org.mpris.MediaPlayer2.") {
				names = append(names, fields[0])
			}
		}
	}
	namesCache[container] = struct {
		at    time.Time
		names []string
	}{time.Now(), names}
	return names
}

func getAll(container, name, iface string) map[string]any {
	code, out := busctl(container, []string{
		"call", name, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "GetAll", "s", iface,
	})
	if code != 0 || out == "" {
		code, out = busctl(container, []string{"get-all", name, "/org/mpris/MediaPlayer2", iface})
	}
	if code != 0 {
		return map[string]any{}
	}
	return asMap(parseJSON(out))
}

var lastArtSrc, lastArtOut string

func artFileURL() string {
	dest := artPath()
	st, err := os.Stat(dest)
	if err != nil || st.Size() < 32 {
		return ""
	}
	return "file://" + dest + "?t=" + strconv.FormatInt(st.ModTime().UnixNano(), 10)
}

func pullArt(container, url, trackKey string) string {
	if url == "" {
		return ""
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	dest := artPath()
	key := url + "|" + trackKey
	if key == lastArtSrc && lastArtOut != "" {
		return lastArtOut
	}
	if strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://") {
		code, _ := run([]string{"curl", "-fsSL", "--max-time", "8", "-o", dest, url}, 10*time.Second)
		if code != 0 {
			return url
		}
		st, err := os.Stat(dest)
		if err != nil || st.Size() < 32 {
			return url
		}
		now := time.Now()
		_ = os.Chtimes(dest, now, now)
		lastArtSrc, lastArtOut = key, artFileURL()
		if lastArtOut == "" {
			return url
		}
		return lastArtOut
	}
	path := url
	if strings.HasPrefix(path, "file://") {
		path = path[7:]
	}
	if !strings.HasPrefix(path, "/") {
		if strings.Contains(url, "://") {
			return url
		}
		return ""
	}
	code, _ := run([]string{"docker", "cp", container + ":" + path, dest}, 6*time.Second)
	if code != 0 {
		return ""
	}
	if _, err := os.Stat(dest); err != nil {
		return ""
	}
	now := time.Now()
	_ = os.Chtimes(dest, now, now)
	lastArtSrc, lastArtOut = key, artFileURL()
	return lastArtOut
}

func snapshotPlayer(container, name string) *snap {
	player := getAll(container, name, "org.mpris.MediaPlayer2.Player")
	status := firstText(player["PlaybackStatus"])
	if status == "" {
		return nil
	}
	meta := asMap(player["Metadata"])
	app := getAll(container, name, "org.mpris.MediaPlayer2")
	identity := firstText(app["Identity"])
	if identity == "" {
		identity = container
	}
	title := firstText(meta["xesam:title"])
	artist := firstText(meta["xesam:artist"])
	album := firstText(meta["xesam:album"])
	art := firstText(meta["mpris:artUrl"])
	length := toSeconds(meta["mpris:length"])
	s := &snap{
		Available:    true,
		Playing:      strings.EqualFold(status, "playing"),
		Source:       "container",
		Container:    container,
		Name:         name,
		Title:        title,
		Artist:       artist,
		Album:        album,
		Identity:     identity,
		DesktopEntry: container,
		TrackID:      firstText(meta["mpris:trackid"]),
		Length:       length,
		Position:     toSeconds(player["Position"]),
		CanToggle:    true,
		CanNext:      asBool(player["CanGoNext"]),
		CanPrevious:  asBool(player["CanGoPrevious"]),
		CanSeek:      asBool(player["CanSeek"]) && length > 0,
	}
	if s.TrackID == "" {
		s.TrackID = "/"
	}
	if art != "" {
		s.ArtURL = pullArt(container, art, s.TrackID+"|"+title+"|"+artist)
	}
	return s
}

func pipewireFallback() *snap {
	code, out := run([]string{"pw-dump"}, 5*time.Second)
	if code != 0 || out == "" {
		return nil
	}
	var data []map[string]any
	if json.Unmarshal([]byte(out), &data) != nil {
		return nil
	}
	for _, obj := range data {
		if !strings.Contains(firstText(obj["type"]), "Node") {
			continue
		}
		info := asMap(obj["info"])
		props := asMap(info["props"])
		if firstText(props["media.class"]) != "Stream/Output/Audio" {
			continue
		}
		if !strings.EqualFold(firstText(info["state"]), "running") {
			continue
		}
		app := firstText(props["application.name"])
		if app == "" {
			app = firstText(props["node.name"])
		}
		mediaName := firstText(props["media.name"])
		if app == "" && mediaName == "" {
			continue
		}
		title, artist := mediaName, app
		low := strings.ToLower(mediaName)
		if mediaName == "" || low == "playback" || low == "audio stream" {
			title, artist = app, ""
		}
		return &snap{
			Available:    true,
			Playing:      true,
			Source:       "pipewire",
			Title:        title,
			Artist:       artist,
			Identity:     or(app, "Audio"),
			DesktopEntry: firstText(props["application.process.binary"]),
		}
	}
	return nil
}

func or(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func empty() snap {
	return snap{TrackID: "/"}
}

func idleLabel(s *snap) bool {
	title := strings.ToLower(strings.TrimSpace(s.Title))
	artist := strings.ToLower(strings.TrimSpace(s.Artist))
	identity := strings.ToLower(strings.TrimSpace(s.Identity))
	if title == "" && artist == "" {
		return true
	}
	shell := map[string]bool{"spotify": true, "spotifity": true, "playback": true, "audio stream": true, "chromium": true, "chrome": true, "firefox": true}
	if shell[title] && (artist == "" || shell[artist]) {
		return true
	}
	return title == identity && (artist == "" || artist == identity)
}

func blob(s *snap) string {
	return strings.ToLower(s.Identity + " " + s.DesktopEntry + " " + s.Container + " " + s.Name)
}

func prefer(list []*snap) *snap {
	if len(list) == 0 {
		return nil
	}
	best := list[0]
	for _, s := range list[1:] {
		// Prefer Spotify over Chrome/browser tabs when both have media.
		if strings.Contains(blob(s), "spotify") && !strings.Contains(blob(best), "spotify") {
			best = s
		}
	}
	return best
}

func isBrowser(s *snap) bool {
	b := blob(s)
	return strings.Contains(b, "chrome") || strings.Contains(b, "chromium") || strings.Contains(b, "firefox") || strings.Contains(b, "zen")
}

func poll() snap {
	var found []*snap
	for _, c := range runningMedia() {
		for _, name := range mprisNames(c) {
			if s := snapshotPlayer(c, name); s != nil {
				found = append(found, s)
			}
		}
	}
	// Spotify with a real track wins over browser media (YouTube in Chrome
	// was stealing the bar while Spotify sat paused with a track loaded).
	var spotify *snap
	for _, s := range found {
		if strings.Contains(blob(s), "spotify") && !idleLabel(s) {
			spotify = s
			break
		}
	}
	if spotify != nil {
		browserOnly := true
		for _, s := range found {
			if s.Playing && !idleLabel(s) && !strings.Contains(blob(s), "spotify") && !isBrowser(s) {
				browserOnly = false
				break
			}
		}
		if spotify.Playing || browserOnly {
			return *spotify
		}
	}
	var playing []*snap
	for _, s := range found {
		if s.Playing && !idleLabel(s) {
			playing = append(playing, s)
		}
	}
	if s := prefer(playing); s != nil {
		return *s
	}
	if pw := pipewireFallback(); pw != nil && !idleLabel(pw) {
		return *pw
	}
	var paused []*snap
	for _, s := range found {
		if (s.Title != "" || s.Artist != "") && !idleLabel(s) {
			paused = append(paused, s)
		}
	}
	if s := prefer(paused); s != nil {
		return *s
	}
	if len(found) > 0 {
		return *found[0]
	}
	return empty()
}

func saveState(s snap) {
	_ = os.MkdirAll(stateDir(), 0o755)
	raw, err := json.Marshal(s)
	if err != nil {
		return
	}
	tmp := statePath() + ".tmp"
	if os.WriteFile(tmp, raw, 0o644) != nil {
		return
	}
	_ = os.Rename(tmp, statePath())
}

func loadState() snap {
	raw, err := os.ReadFile(statePath())
	if err != nil {
		return empty()
	}
	var s snap
	if json.Unmarshal(raw, &s) != nil {
		return empty()
	}
	return s
}

func callPlayer(container, name, method string, extra []string) int {
	args := []string{"call", name, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", method}
	args = append(args, extra...)
	code, _ := busctl(container, args)
	return code
}

func ctl(action, arg string) int {
	s := loadState()
	if s.Source != "container" || s.Container == "" || s.Name == "" {
		return 1
	}
	switch action {
	case "toggle":
		return callPlayer(s.Container, s.Name, "PlayPause", nil)
	case "next":
		return callPlayer(s.Container, s.Name, "Next", nil)
	case "previous":
		return callPlayer(s.Container, s.Name, "Previous", nil)
	case "seek":
		ratio, err := strconv.ParseFloat(arg, 64)
		if err != nil {
			return 1
		}
		if ratio < 0 {
			ratio = 0
		}
		if ratio > 1 {
			ratio = 1
		}
		if s.Length <= 0 {
			return 1
		}
		usec := strconv.FormatInt(int64(ratio*s.Length*1_000_000), 10)
		track := s.TrackID
		if track == "" {
			track = "/"
		}
		return callPlayer(s.Container, s.Name, "SetPosition", []string{"o", track, "x", usec})
	default:
		return 1
	}
}

func loop() {
	last := ""
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	for {
		s := poll()
		saveState(s)
		var buf bytes.Buffer
		e := json.NewEncoder(&buf)
		e.SetEscapeHTML(false)
		_ = e.Encode(s)
		line := strings.TrimSpace(buf.String())
		if line != last {
			_, _ = os.Stdout.WriteString(line + "\n")
			last = line
		}
		wait := 2 * time.Second
		if s.Playing {
			wait = time.Second
		}
		time.Sleep(wait)
	}
}

func Main(args []string) {
	os.Args = append([]string{"mpris"}, args...)
	if len(os.Args) > 1 {
		arg := ""
		if len(os.Args) > 2 {
			arg = os.Args[2]
		}
		os.Exit(ctl(os.Args[1], arg))
	}
	loop()
}
