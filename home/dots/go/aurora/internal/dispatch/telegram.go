package dispatch

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"aurora/internal/execx"
)

func telegramLinkMain(_ []string) int {
	ensureHostEnv()
	home := execx.Home()
	files := []string{
		filepath.Join(home, "programs/telegram-1/ipc/telegram.url"),
		filepath.Join(home, "programs/chrome-dd/ipc/telegram.url"),
		filepath.Join(home, "programs/chrome-az/ipc/telegram.url"),
		filepath.Join(home, "programs/chrome-hika/ipc/telegram.url"),
		filepath.Join(home, "programs/firefox/ipc/telegram.url"),
		filepath.Join(home, "programs/zen/ipc/telegram.url"),
		filepath.Join(home, "programs/ipc/telegram.url"),
	}

	var url string
	for _, file := range files {
		st, err := os.Stat(file)
		if err != nil || st.Size() == 0 {
			continue
		}
		b, err := os.ReadFile(file)
		_ = os.WriteFile(file, nil, 0o644)
		if err != nil {
			continue
		}
		url = strings.TrimSpace(string(b))
		if url != "" {
			break
		}
	}
	if url == "" {
		return 0
	}

	bin, err := exec.LookPath("Telegram")
	if err != nil {
		bin = "Telegram"
	}
	err = syscall.Exec(bin, []string{bin, "--", url}, os.Environ())
	if err != nil {
		return 1
	}
	return 0
}
