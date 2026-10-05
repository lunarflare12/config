package finderaction

import (
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

func usage() {
	fmt.Fprintln(os.Stderr, "finder-action.sh new-window|info|duplicate|alias|preview|compress|share|color [--] PATHS...")
}

func zenityBin() string {
	return execx.Look("zenity")
}

func finderInvoke(path string) (string, []string) {
	if s := execx.Look("finder"); s != "" {
		return s, []string{s, path}
	}
	if s := execx.Look("aurora"); s != "" {
		return s, []string{s, "finder", path}
	}
	s := "/run/current-system/sw/bin/thunar"
	return s, []string{s, path}
}

func infoOne(p string) string {
	kind := "File"
	if st, err := os.Stat(p); err == nil && st.IsDir() {
		kind = "Folder"
	}
	size := "—"
	if code, out := execx.Run(5*time.Second, "du", "-sh", "--", p); code == 0 {
		fields := strings.Fields(out)
		if len(fields) > 0 {
			size = fields[0]
		}
	}
	mime := "unknown"
	if code, out := execx.Run(3*time.Second, "file", "--mime-type", "-b", "--", p); code == 0 {
		mime = strings.TrimSpace(out)
	}
	mtime := ""
	if st, err := os.Stat(p); err == nil {
		mtime = st.ModTime().Format("02 Jan 2006 at 15:04")
	} else {
		mtime = "unknown"
	}
	return fmt.Sprintf("%s\n\nKind: %s\nSize: %s\nType: %s\nModified: %s\nWhere: %s\n",
		filepath.Base(p), kind, size, mime, mtime, filepath.Dir(p))
}

func preview(paths []string) int {
	qs := execx.Look("qs")
	if qs == "" {
		user := os.Getenv("USER")
		if user == "" {
			user = "dd"
		}
		cand := "/etc/profiles/per-user/" + user + "/bin/qs"
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			qs = cand
		}
	}
	if qs == "" {
		fmt.Fprintln(os.Stderr, "finder-action: qs not found")
		return 1
	}
	blob := strings.Join(paths, "\n") + "\n"
	err := syscall.Exec(qs, []string{qs, "ipc", "call", "preview", "toggle", blob}, os.Environ())
	if err != nil {
		fmt.Fprintln(os.Stderr, "finder-action:", err)
		return 1
	}
	return 0
}

func colorOne(p string) int {
	st, err := os.Stat(p)
	if err != nil || !st.IsDir() {
		return 0
	}
	z := zenityBin()
	if z == "" {
		return 1
	}
	cmd := exec.Command(z, "--list", "--radiolist",
		"--title=Customise Folder", "--text="+filepath.Base(p),
		"--hide-header", "--column=sel", "--column=Colour",
		"--width=280", "--height=360",
		"TRUE", "Default",
		"FALSE", "Red",
		"FALSE", "Orange",
		"FALSE", "Yellow",
		"FALSE", "Green",
		"FALSE", "Blue",
		"FALSE", "Purple",
		"FALSE", "Grey",
		"FALSE", "Black",
	)
	out, err := cmd.Output()
	pick := strings.TrimSpace(string(out))
	if pick == "" {
		return 0
	}
	icons := map[string]string{
		"Red":    "folder-red",
		"Orange": "folder-orange",
		"Yellow": "folder-yellow",
		"Green":  "folder-green",
		"Blue":   "folder-blue",
		"Purple": "folder-purple",
		"Grey":   "folder-grey",
		"Black":  "folder-black",
	}
	switch pick {
	case "Default":
		_ = exec.Command("gio", "set", "-t", "unset", "--", p, "metadata::custom-icon-name").Run()
	default:
		icon, ok := icons[pick]
		if !ok {
			return 0
		}
		_ = exec.Command("gio", "set", "-t", "string", "--", p, "metadata::custom-icon-name", icon).Run()
	}
	now := time.Now()
	_ = os.Chtimes(p, now, now)
	return 0
}

func uniqueDest(dir, name, suffix string) string {
	dest := filepath.Join(dir, name+" "+suffix)
	n := 2
	for {
		if _, err := os.Stat(dest); err != nil {
			return dest
		}
		dest = filepath.Join(dir, fmt.Sprintf("%s %s %d", name, suffix, n))
		n++
	}
}

func duplicateOne(src string) int {
	dir := filepath.Dir(src)
	name := filepath.Base(src)
	dest := uniqueDest(dir, name, "copy")
	cmd := exec.Command("cp", "-a", "--", src, dest)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return 1
	}
	return 0
}

func aliasOne(src string) int {
	dir := filepath.Dir(src)
	name := filepath.Base(src)
	dest := uniqueDest(dir, name, "alias")
	if err := os.Symlink(src, dest); err != nil {
		return 1
	}
	return 0
}

func fileURI(p string) string {
	abs, err := filepath.Abs(p)
	if err != nil {
		abs = p
	}
	return (&url.URL{Scheme: "file", Path: filepath.ToSlash(abs)}).String()
}

func shareFiles(paths []string) int {
	var uris strings.Builder
	for _, p := range paths {
		uris.WriteString(fileURI(p))
		uris.WriteByte('\n')
	}
	if wl := execx.Look("wl-copy"); wl != "" {
		cmd := exec.Command(wl, "--type", "text/uri-list")
		cmd.Stdin = strings.NewReader(uris.String())
		_ = cmd.Run()
	}
	if ns := execx.Look("notify-send"); ns != "" {
		_ = exec.Command(ns, "Finder", "Copied "+filepath.Base(paths[0])+" for sharing").Run()
	}
	return 0
}

func execReplace(bin string, argv []string) int {
	err := syscall.Exec(bin, argv, os.Environ())
	if err != nil {
		fmt.Fprintln(os.Stderr, "finder-action:", err)
		return 1
	}
	return 0
}

func Main(args []string) int {
	if len(args) < 1 {
		usage()
		return 2
	}
	cmd := args[0]
	rest := args[1:]
	if len(rest) > 0 && rest[0] == "--" {
		rest = rest[1:]
	}
	if len(rest) < 1 {
		usage()
		return 2
	}

	switch cmd {
	case "new-window":
		bin, args := finderInvoke(rest[0])
		return execReplace(bin, args)
	case "info":
		var text strings.Builder
		for _, p := range rest {
			text.WriteString(infoOne(p))
			text.WriteString("\n\n")
		}
		if z := zenityBin(); z != "" {
			return execReplace(z, []string{z, "--info", "--title=Info", "--width=420", "--text=" + text.String()})
		}
		fmt.Print(text.String())
		return 0
	case "duplicate":
		for _, p := range rest {
			if duplicateOne(p) != 0 {
				return 1
			}
		}
		return 0
	case "alias":
		for _, p := range rest {
			if aliasOne(p) != 0 {
				return 1
			}
		}
		return 0
	case "preview":
		return preview(rest)
	case "compress":
		bin := execx.Look("file-roller")
		if bin == "" {
			fmt.Fprintln(os.Stderr, "finder-action: file-roller not found")
			return 1
		}
		return execReplace(bin, append([]string{bin, "--add"}, rest...))
	case "share":
		return shareFiles(rest)
	case "color":
		return colorOne(rest[0])
	default:
		usage()
		return 2
	}
}
