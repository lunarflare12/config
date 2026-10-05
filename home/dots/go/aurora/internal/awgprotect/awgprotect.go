package awgprotect

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

var ifaceRE = regexp.MustCompile(`^[A-Za-z0-9_=+.-]{1,15}$`)

func endpointFromConf(iface string) string {
	for _, conf := range []string{
		"/etc/amnesia/" + iface + ".conf",
		"/etc/amnezia/" + iface + ".conf",
		"/etc/wireguard/" + iface + ".conf",
	} {
		b, err := os.ReadFile(conf)
		if err != nil {
			continue
		}
		var last string
		for _, line := range strings.Split(string(b), "\n") {
			line = strings.TrimSpace(line)
			if !strings.HasPrefix(strings.ToLower(line), "endpoint") {
				continue
			}
			if i := strings.IndexByte(line, '='); i >= 0 {
				v := strings.TrimSpace(line[i+1:])
				if j := strings.IndexByte(v, '#'); j >= 0 {
					v = strings.TrimSpace(v[:j])
				}
				last = v
			}
		}
		if last != "" {
			return last
		}
	}
	return ""
}

func hostOf(ep string) string {
	if strings.HasPrefix(ep, "[") {
		ep = strings.TrimPrefix(ep, "[")
		if i := strings.IndexByte(ep, ']'); i >= 0 {
			return ep[:i]
		}
	}
	if i := strings.LastIndexByte(ep, ':'); i >= 0 {
		return ep[:i]
	}
	return ep
}

func ipv4Of(host string) string {
	ips, err := net.LookupIP(host)
	if err != nil {
		return ""
	}
	for _, ip := range ips {
		if v4 := ip.To4(); v4 != nil {
			return v4.String()
		}
	}
	return ""
}

func routeParts(ip string) (via, dev string) {
	out, err := exec.Command("ip", "-4", "route", "get", ip).Output()
	if err != nil {
		return "", ""
	}
	fields := strings.Fields(string(out))
	for i, f := range fields {
		if f == "via" && i+1 < len(fields) {
			via = fields[i+1]
		}
		if f == "dev" && i+1 < len(fields) {
			dev = fields[i+1]
		}
	}
	return via, dev
}

func applyRoute(ip, via, dev string) {
	if ip == "" || dev == "" {
		return
	}
	if via != "" {
		_ = exec.Command("ip", "route", "replace", ip+"/32", "via", via, "dev", dev).Run()
	} else {
		_ = exec.Command("ip", "route", "replace", ip+"/32", "dev", dev).Run()
	}
}

func Main(args []string) int {
	if len(args) < 2 || !ifaceRE.MatchString(args[1]) {
		fmt.Fprintln(os.Stderr, "usage: aurora awg-protect up|down IFACE")
		return 2
	}
	action, iface := args[0], args[1]
	stateDir := "/run/aurora"
	state := filepath.Join(stateDir, "awg-endpoint."+iface)

	switch action {
	case "up":
		_ = os.MkdirAll(stateDir, 0o755)
		if b, err := os.ReadFile(state); err == nil {
			parts := strings.Fields(string(b))
			if len(parts) >= 1 {
				ip := parts[0]
				via, dev := "", ""
				for i := 1; i+1 < len(parts); i++ {
					if parts[i] == "via" {
						via = parts[i+1]
					}
					if parts[i] == "dev" {
						dev = parts[i+1]
					}
				}
				applyRoute(ip, via, dev)
				return 0
			}
		}
		ep := endpointFromConf(iface)
		if ep == "" {
			return 0
		}
		ipaddr := ipv4Of(hostOf(ep))
		if ipaddr == "" {
			return 0
		}
		via, dev := routeParts(ipaddr)
		if dev == "" || dev == iface {
			return 0
		}
		applyRoute(ipaddr, via, dev)
		if via != "" {
			_ = os.WriteFile(state, []byte(fmt.Sprintf("%s via %s dev %s\n", ipaddr, via, dev)), 0o644)
		} else {
			_ = os.WriteFile(state, []byte(fmt.Sprintf("%s dev %s\n", ipaddr, dev)), 0o644)
		}
		return 0
	case "down":
		ipaddr := ""
		if b, err := os.ReadFile(state); err == nil {
			parts := strings.Fields(string(b))
			if len(parts) > 0 {
				ipaddr = parts[0]
			}
			_ = os.Remove(state)
		}
		if ipaddr == "" {
			ep := endpointFromConf(iface)
			if ep != "" {
				ipaddr = ipv4Of(hostOf(ep))
			}
		}
		if ipaddr != "" {
			_ = exec.Command("ip", "route", "del", ipaddr+"/32").Run()
		}
		return 0
	default:
		fmt.Fprintln(os.Stderr, "usage: aurora awg-protect up|down IFACE")
		return 2
	}
}
