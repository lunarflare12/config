package insta360

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

func wake() {
	if p := execx.Look("insta360-wake"); p != "" {
		_ = exec.Command("sudo", "-n", p).Run()
	}
	ents, _ := os.ReadDir("/sys/bus/usb/devices")
	for _, e := range ents {
		base := filepath.Join("/sys/bus/usb/devices", e.Name())
		b, err := os.ReadFile(filepath.Join(base, "idVendor"))
		if err != nil || strings.TrimSpace(string(b)) != "2e1a" {
			continue
		}
		_ = os.WriteFile(filepath.Join(base, "power", "control"), []byte("on\n"), 0o644)
		_ = os.WriteFile(filepath.Join(base, "power", "autosuspend"), []byte("-1\n"), 0o644)
	}
}

func linkGUI(args []string) int {
	wake()
	user := os.Getenv("USER")
	if user == "" {
		user = "dd"
	}
	bin := "/etc/profiles/per-user/" + user + "/bin/insta360linkgui"
	if st, err := os.Stat(bin); err != nil || st.IsDir() {
		bin = execx.Look("insta360linkgui")
	}
	if bin == "" {
		fmt.Fprintln(os.Stderr, "insta360linkgui not found")
		return 127
	}
	cmd := exec.Command(bin, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func usbNode() string {
	ents, _ := os.ReadDir("/sys/bus/usb/devices")
	for _, e := range ents {
		base := filepath.Join("/sys/bus/usb/devices", e.Name())
		b, err := os.ReadFile(filepath.Join(base, "idVendor"))
		if err != nil || strings.TrimSpace(string(b)) != "2e1a" {
			continue
		}
		busB, err1 := os.ReadFile(filepath.Join(base, "busnum"))
		devB, err2 := os.ReadFile(filepath.Join(base, "devnum"))
		if err1 != nil || err2 != nil {
			continue
		}
		bus, _ := strconv.Atoi(strings.TrimSpace(string(busB)))
		dev, _ := strconv.Atoi(strings.TrimSpace(string(devB)))
		path := fmt.Sprintf("/dev/bus/usb/%03d/%03d", bus, dev)
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	return ""
}

func captureNode() string {
	matches, _ := filepath.Glob("/dev/v4l/by-id/usb-Insta360_*-video-index0")
	for _, n := range matches {
		if _, err := os.Stat(n); err == nil {
			return n
		}
	}
	return ""
}

func applyPreset(cap string) {
	ctl := execx.Look("linkctl")
	if ctl == "" {
		return
	}
	cmds := [][]string{
		{"-d", cap, "tracking", "on"},
		{"-d", cap, "frame", "head"},
		{"-d", cap, "zoom", "200"},
		{"-d", cap, "pan", "0"},
		{"-d", cap, "tilt", "-28800"},
		{"-d", cap, "focus", "auto"},
	}
	for _, a := range cmds {
		_ = exec.Command(ctl, a...).Run()
	}
}

func hold() int {
	for {
		usb := usbNode()
		if usb == "" {
			time.Sleep(2 * time.Second)
			continue
		}
		f, err := os.OpenFile(usb, os.O_RDWR, 0)
		if err != nil {
			time.Sleep(2 * time.Second)
			continue
		}
		var cap string
		for i := 0; i < 20; i++ {
			cap = captureNode()
			if cap != "" {
				break
			}
			time.Sleep(250 * time.Millisecond)
		}
		if cap != "" {
			go applyPreset(cap)
		}
		for {
			if _, err := os.Stat(usb); err != nil {
				break
			}
			time.Sleep(5 * time.Second)
		}
		_ = f.Close()
	}
}

func Main(args []string) int {
	if len(args) > 0 && args[0] == "hold" {
		return hold()
	}
	return linkGUI(args)
}
