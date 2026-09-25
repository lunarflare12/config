package monitor

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

func readLine(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	sc := bufio.NewScanner(strings.NewReader(string(b)))
	if sc.Scan() {
		return strings.TrimSpace(sc.Text())
	}
	return ""
}

func cpuCounters() (total, idle uint64) {
	fs := strings.Fields(readLine("/proc/stat"))
	if len(fs) < 9 {
		return 0, 0
	}
	var nums [8]uint64
	for i := 0; i < 8; i++ {
		n, _ := strconv.ParseUint(fs[i+1], 10, 64)
		nums[i] = n
		total += n
	}
	idle = nums[3] + nums[4]
	return total, idle
}

func meminfo() (mt, ma, st, sf uint64) {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fs := strings.Fields(sc.Text())
		if len(fs) < 2 {
			continue
		}
		n, _ := strconv.ParseUint(fs[1], 10, 64)
		switch fs[0] {
		case "MemTotal:":
			mt = n
		case "MemAvailable:":
			ma = n
		case "SwapTotal:":
			st = n
		case "SwapFree:":
			sf = n
		}
	}
	return
}

func cpuTemp() int {
	ents, err := os.ReadDir("/sys/class/hwmon")
	if err != nil {
		return 0
	}
	read := func(name string) int {
		b, err := os.ReadFile("/sys/class/hwmon/" + name + "/temp1_input")
		if err != nil {
			return 0
		}
		n, err := strconv.Atoi(strings.TrimSpace(string(b)))
		if err != nil {
			return 0
		}
		return n / 1000
	}
	for _, e := range ents {
		name := strings.TrimSpace(string(mustRead("/sys/class/hwmon/" + e.Name() + "/name")))
		if name == "k10temp" {
			if t := read(e.Name()); t > 0 {
				return t
			}
		}
	}
	for _, e := range ents {
		name := strings.TrimSpace(string(mustRead("/sys/class/hwmon/" + e.Name() + "/name")))
		switch name {
		case "nvme", "spd5118", "amdgpu", "":
			continue
		}
		if t := read(e.Name()); t > 0 {
			return t
		}
	}
	return 0
}

func mustRead(path string) []byte {
	b, _ := os.ReadFile(path)
	return b
}

func defaultNIC() string {
	f, err := os.Open("/proc/net/route")
	if err == nil {
		sc := bufio.NewScanner(f)
		if sc.Scan() {
		}
		for sc.Scan() {
			fs := strings.Fields(sc.Text())
			if len(fs) < 2 {
				continue
			}
			if fs[1] == "00000000" && fs[0] != "lo" {
				_ = f.Close()
				return fs[0]
			}
		}
		_ = f.Close()
	}
	dev, err := os.Open("/proc/net/dev")
	if err != nil {
		return "enp7s0"
	}
	defer dev.Close()
	sc := bufio.NewScanner(dev)
	for i := 0; sc.Scan(); i++ {
		if i < 2 {
			continue
		}
		line := strings.TrimSpace(sc.Text())
		name, _, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		name = strings.TrimSpace(name)
		if strings.HasPrefix(name, "en") || strings.HasPrefix(name, "eth") || strings.HasPrefix(name, "wl") {
			return name
		}
	}
	return "enp7s0"
}

func netBytes(nic string) (rx, tx uint64) {
	f, err := os.Open("/proc/net/dev")
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		name, rest, ok := strings.Cut(line, ":")
		if !ok || strings.TrimSpace(name) != nic {
			continue
		}
		fs := strings.Fields(rest)
		if len(fs) < 9 {
			return
		}
		rx, _ = strconv.ParseUint(fs[0], 10, 64)
		tx, _ = strconv.ParseUint(fs[8], 10, 64)
		return
	}
	return
}

func gpuStats() (util, temp, vramUsed, vramTotal int) {
	temp = -1
	code, out := execx.Run(1500*time.Millisecond, "nvidia-smi",
		"--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
		"--format=csv,noheader,nounits")
	if code != 0 || out == "" {
		return
	}
	line := strings.Split(out, "\n")[0]
	line = strings.ReplaceAll(line, " ", "")
	fs := strings.Split(line, ",")
	if len(fs) < 4 {
		return
	}
	util, _ = strconv.Atoi(fs[0])
	temp, _ = strconv.Atoi(fs[1])
	vramUsed, _ = strconv.Atoi(fs[2])
	vramTotal, _ = strconv.Atoi(fs[3])
	return
}

func dfBytes(path string) (used, total uint64) {
	code, out := execx.Run(1500*time.Millisecond, "df", "-B1", "--output=used,size", path)
	if code != 0 {
		return
	}
	sc := bufio.NewScanner(strings.NewReader(out))
	if sc.Scan() {
		// header
	}
	if sc.Scan() {
		fs := strings.Fields(sc.Text())
		if len(fs) >= 2 {
			used, _ = strconv.ParseUint(fs[0], 10, 64)
			total, _ = strconv.ParseUint(fs[1], 10, 64)
		}
	}
	return
}

func Main(args []string) int {
	light := len(args) > 0 && args[0] == "light"
	total, idle := cpuCounters()
	mt, ma, st, sf := meminfo()
	rx, tx := netBytes(defaultNIC())
	gpuUtil, gpuTemp, vramUsed, vramTotal := 0, -1, 0, 0
	var du, dt, hu, ht uint64
	if !light {
		gpuUtil, gpuTemp, vramUsed, vramTotal = gpuStats()
		du, dt = dfBytes("/")
		hu, ht = dfBytes("/home")
	}
	fmt.Printf("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
		total, idle, mt, ma, cpuTemp(), rx, tx,
		gpuUtil, gpuTemp, vramUsed, vramTotal, st, sf, du, dt, hu, ht)
	return 0
}
