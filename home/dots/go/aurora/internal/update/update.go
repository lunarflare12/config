package update

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"aurora/internal/execx"
)

func notify(urgency, body string) {
	_ = exec.Command("notify-send", "-a", "Aurora", "-u", urgency, "--", "System update", body).Run()
}

func waitEnter() {
	fmt.Print("\nPress enter to close.\n")
	var b [1]byte
	_, _ = os.Stdin.Read(b[:])
}

func Main(args []string) int {
	repo := filepath.Join(execx.Home(), "Documents", "projects", "config")
	if err := os.Chdir(repo); err != nil {
		fmt.Printf("Could not open %s\n", repo)
		notify("critical", "Could not open "+repo)
		waitEnter()
		return 1
	}
	beforeOut, _ := exec.Command("git", "rev-parse", "--short", "HEAD").Output()
	before := string(beforeOut)
	if before == "" {
		before = "unknown"
	} else if before[len(before)-1] == '\n' {
		before = before[:len(before)-1]
	}

	fmt.Println("==> git pull --ff-only")
	pullMsg := ""
	after := before
	if err := exec.Command("git", "pull", "--ff-only").Run(); err == nil {
		afterOut, _ := exec.Command("git", "rev-parse", "--short", "HEAD").Output()
		after = string(afterOut)
		if after != "" && after[len(after)-1] == '\n' {
			after = after[:len(after)-1]
		}
		if before == after {
			pullMsg = "Already up to date (" + after + ")."
		} else {
			pullMsg = "Pulled " + before + " → " + after + "."
		}
	} else {
		pullMsg = "Git pull skipped (could not fast-forward)."
		fmt.Println("\n" + pullMsg)
	}

	fmt.Printf("\n==> nixos-rebuild switch --flake %s#nixos\n", repo)
	cmd := exec.Command("sudo", "nixos-rebuild", "switch", "--flake", repo+"#nixos")
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err == nil {
		fmt.Println("\nDone.")
		notify("normal", pullMsg+" Rebuild finished.")
		waitEnter()
		return 0
	}
	fmt.Println("\nRebuild failed.")
	notify("critical", pullMsg+" Rebuild failed.")
	waitEnter()
	return 1
}
