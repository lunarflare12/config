package lab

type publicTunnel struct {
	Name   string `json:"name"`
	Label  string `json:"label"`
	Folder string `json:"folder"`
	Up     bool   `json:"up"`
	Kind   string `json:"kind"`
}

func publicTunnels(rows []tunnelRow, kind string) []publicTunnel {
	out := make([]publicTunnel, 0, len(rows))
	for _, row := range rows {
		folder := row.Folder
		if folder == "" {
			folder = ""
		}
		out = append(out, publicTunnel{
			Name:   row.Name,
			Label:  orDefault(row.Label, row.Name),
			Folder: folder,
			Up:     row.Up,
			Kind:   kind,
		})
	}
	return out
}

func status(full bool) map[string]any {
	lab, apps := listDocker(full)
	return map[string]any{
		"vms":         vms(),
		"containers":  lab,
		"apps":        apps,
		"wireguard":   publicTunnels(configs(wgDirs), "wireguard"),
		"amnezia":     publicTunnels(configs(awgDirs), "amnezia"),
		"vless":       publicTunnels(vlessConfigs(), "vless"),
		"openconnect": publicTunnels(openconnectConfigs(), "openconnect"),
	}
}
