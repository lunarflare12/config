package state

import (
	"encoding/json"
	"os"
)

type appLayout struct {
	Launchpad []any `json:"launchpad"`
}

func scoreLayout(path string) (folders, total int) {
	b, err := os.ReadFile(path)
	if err != nil {
		return -1, -1
	}
	var d appLayout
	if json.Unmarshal(b, &d) != nil {
		return -1, -1
	}
	for _, x := range d.Launchpad {
		if _, ok := x.(map[string]any); ok {
			folders++
		}
	}
	return folders, len(d.Launchpad)
}

// PreferLayoutBackup keeps the richer launchpad layout when sync races wipe pins.
func PreferLayoutBackup(layoutPath, backupPath string) error {
	if layoutPath == "" || backupPath == "" {
		return nil
	}
	if st, err := os.Stat(layoutPath); err != nil || st.Size() == 0 {
		return nil
	}
	if st, err := os.Stat(backupPath); err != nil || st.Size() == 0 {
		return nil
	}
	lf, lt := scoreLayout(layoutPath)
	bf, bt := scoreLayout(backupPath)
	if bf > lf || (bf == lf && bt > lt) {
		data, err := os.ReadFile(backupPath)
		if err != nil {
			return err
		}
		return os.WriteFile(layoutPath, data, 0o644)
	}
	return nil
}

func Main(args []string) int {
	if len(args) >= 1 && args[0] == "prefer-layout-backup" {
		layout := ""
		backup := ""
		if len(args) >= 2 {
			layout = args[1]
		}
		if len(args) >= 3 {
			backup = args[2]
		}
		_ = PreferLayoutBackup(layout, backup)
		return 0
	}
	return 2
}
