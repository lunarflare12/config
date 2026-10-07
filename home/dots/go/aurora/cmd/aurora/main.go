package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"aurora/internal/activate"
	"aurora/internal/apps"
	"aurora/internal/awgprotect"
	"aurora/internal/box"
	"aurora/internal/brightness"
	"aurora/internal/container"
	"aurora/internal/cursor"
	auroradispatch "aurora/internal/dispatch"
	"aurora/internal/emoji"
	"aurora/internal/finder"
	"aurora/internal/finderaction"
	"aurora/internal/fossilize"
	"aurora/internal/game"
	"aurora/internal/helpers"
	"aurora/internal/hyprfix"
	"aurora/internal/insta360"
	"aurora/internal/lab"
	"aurora/internal/libreofficeui"
	"aurora/internal/monitor"
	"aurora/internal/mpris"
	"aurora/internal/obs"
	"aurora/internal/openconnect"
	"aurora/internal/protect"
	"aurora/internal/reaper"
	"aurora/internal/shade"
	"aurora/internal/shader"
	"aurora/internal/shot"
	"aurora/internal/spotify"
	"aurora/internal/state"
	"aurora/internal/steamlock"
	"aurora/internal/update"
	"aurora/internal/wallpaper"
)

func usage() {
	fmt.Fprintln(os.Stderr, `aurora <cmd> [args]
  wallpaper|hypr-fix|fossilize|monitor|helpers|session|mpris|reaper
  screenshot|cursor|activate|lab|brightness|emoji|state|spotify
  shade|steam-lock|protect-shaders|game|apps|shader
  finder|finder-action|update|awg-protect|openconnect
  box|wayland-box|dispatch|obs|insta360|libreoffice-ui|container`)
}

func dispatch(cmd string, args []string) int {
	if fields := strings.Fields(cmd); len(fields) > 1 {
		cmd = fields[0]
		args = append(fields[1:], args...)
	}
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
	case "lab", "lab-ctl", "vpn-ctl":
		return lab.Main(args)
	case "brightness", "brightnessctl":
		return brightness.Main(args)
	case "emoji":
		return emoji.Main(args)
	case "state":
		return state.Main(args)
	case "spotify":
		return spotify.Main(args)
	case "shade", "hypr-window-shade":
		return shade.Main(args)
	case "steam-lock", "steam-lock-shaders":
		return steamlock.Main(args)
	case "protect-shaders", "protect-shader-caches":
		return protect.Main(args)
	case "game":
		return game.Main(args)
	case "apps":
		return apps.Main(args)
	case "shader", "shader-ctl":
		return shader.Main(args)
	case "finder":
		return finder.Main(args)
	case "finder-action":
		return finderaction.Main(args)
	case "update", "system-update":
		return update.Main(args)
	case "awg-protect", "awg-protect-endpoint":
		return awgprotect.Main(args)
	case "openconnect", "openconnect-tunnel":
		return openconnect.Main(args)
	case "box", "wayland-box":
		return box.Main(args)
	case "dispatch":
		return auroradispatch.Main(args)
	case "obs":
		return obs.Main(args)
	case "insta360":
		return insta360.Main(args)
	case "libreoffice-ui":
		return libreofficeui.Main(args)
	case "container":
		return container.Main(args)
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
	case "vpn-ctl", "lab-ctl":
		os.Exit(lab.Main(args))
	case "brightnessctl":
		os.Exit(brightness.Main(args))
	case "spotify-theme":
		os.Exit(spotify.Main(append([]string{"theme"}, args...)))
	case "shader-ctl":
		os.Exit(shader.Main(args))
	case "generals":
		os.Exit(game.Main(append([]string{"generals"}, args...)))
	}
	if len(args) == 0 {
		usage()
		os.Exit(2)
	}
	os.Exit(dispatch(args[0], args[1:]))
}
