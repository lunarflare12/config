package fossilize

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func nproc() int {
	b, err := os.ReadFile("/sys/devices/system/cpu/online")
	if err != nil {
		return 16
	}
	s := strings.TrimSpace(string(b))
	if i := strings.LastIndex(s, "-"); i >= 0 {
		n, err := strconv.Atoi(s[i+1:])
		if err == nil {
			return n + 1
		}
	}
	return 16
}

func lastTwo() string {
	n := nproc()
	if n >= 6 {
		return strconv.Itoa(n-2) + "-" + strconv.Itoa(n-1)
	}
	return "0-1"
}

func capOnce() {
	mask := lastTwo()
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return
	}
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid <= 1 {
			continue
		}
		cmdb, err := os.ReadFile(filepath.Join("/proc", e.Name(), "cmdline"))
		if err != nil {
			continue
		}
		cmd := strings.ReplaceAll(string(cmdb), "\x00", " ")
		if !strings.Contains(cmd, "fossilize_replay") {
			continue
		}
		_ = exec.Command("taskset", "-cp", mask, e.Name()).Run()
		_ = exec.Command("renice", "-n", "19", "-p", e.Name()).Run()
		_ = exec.Command("ionice", "-c", "3", "-p", e.Name()).Run()
	}
}

func Loop() {
	for {
		capOnce()
		time.Sleep(15 * time.Second)
	}
}

func Main(args []string) int {
	if len(args) > 0 && (args[0] == "loop" || args[0] == "watch") {
		Loop()
		return 0
	}
	capOnce()
	return 0
}
