package main

import (
	"fmt"
	"os"
	"path/filepath"

	"aurora/internal/activate"
	"aurora/internal/cursor"
	"aurora/internal/fossilize"
	"aurora/internal/helpers"
	"aurora/internal/hyprfix"
	"aurora/internal/monitor"
	"aurora/internal/mpris"
	"aurora/internal/reaper"
	"aurora/internal/shot"
	"aurora/internal/wallpaper"
)

func usage() {
	fmt.Fprintln(os.Stderr, `aurora <cmd> [args]
  wallpaper [set|apply|load|ensure|daemon|path|thumbs] [path]
  hypr-fix [loop]
  fossilize [loop]
  monitor [light]
  helpers [kill-qs|session]
  session
  mpris [ctl args]
  reaper [watch|quit-orphans|name [action]]
  screenshot X Y W H
  cursor [load|set] [id] [size] [theme]
  activate [--probe] name...`)
}

func dispatch(cmd string, args []string) int {
	switch cmd {
	case "wallpaper", "wp":
		return wallpaper.Main(args)
	case "hypr-fix", "hyprfix", "hypr":
		return hyprfix.Main(args)
	case "fossilize", "cap-fossilize":
		return fossilize.Main(args)
	case "monitor", "sysmon":
		return monitor.Main(args)
	case "helpers", "kill-qs":
		return helpers.Main(args)
	case "session", "session-start":
		return helpers.Main(append([]string{"session"}, args...))
	case "mpris":
		mpris.Main(args)
		return 0
	case "reaper":
		reaper.Main(args)
		return 0
	case "screenshot", "shot":
		return shot.Main(args)
	case "cursor":
		return cursor.Main(args)
	case "activate", "activate-existing":
		return activate.Main(args)
	default:
		usage()
		return 2
	}
}

func main() {
	base := filepath.Base(os.Args[0])
	args := os.Args[1:]
	switch base {
	case "aurora-mpris":
		mpris.Main(args)
		return
	case "aurora-reaper":
		reaper.Main(args)
		return
	case "aurora-wallpaper":
		os.Exit(wallpaper.Main(args))
	case "aurora-hypr-fix":
		os.Exit(hyprfix.Main(args))
	case "aurora-fossilize":
		os.Exit(fossilize.Main(args))
	case "aurora-monitor":
		os.Exit(monitor.Main(args))
	case "aurora-helpers":
		os.Exit(helpers.Main(args))
	}
	if len(args) == 0 {
		usage()
		os.Exit(2)
	}
	os.Exit(dispatch(args[0], args[1:]))
}
