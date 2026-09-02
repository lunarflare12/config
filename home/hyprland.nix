{
  lib,
  pkgs,
  params,
  ...
}:

let
  monitorLua = lib.concatMapStrings (
    monitor:
    let
      output = ''output = "${monitor.output or ""}", '';
      transform = lib.optionalString (monitor ? transform) ''transform = ${toString monitor.transform}, '';
    in
    ''
      hl.monitor({ ${output}mode = "${monitor.mode}", position = "${monitor.position}", scale = ${toString monitor.scale}, ${transform}})
    ''
  ) params.monitors;

  polkitAgent = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
in
{
  xdg.configFile."hypr/hyprland.lua".source = ./dots/hypr/hyprland.lua;
  xdg.configFile."hypr/config/animations.lua".source = ./dots/hypr/config/animations.lua;
  xdg.configFile."hypr/config/decorations.lua".source = ./dots/hypr/config/decorations.lua;
  xdg.configFile."hypr/config/windows.lua".source = ./dots/hypr/config/windows.lua;
  xdg.configFile."hypr/config/keybinds.lua".source = ./dots/hypr/config/keybinds.lua;

  xdg.configFile."hypr/config/programs.lua".text = ''
    return {
        terminal = "${params.terminal}",
        browser = "${params.browser}",
        file_manager = "${params.fileManager}",
        scripts = os.getenv("HOME") .. "/.config/scripts",
    }
  '';

  xdg.configFile."hypr/config/monitors.lua".text = monitorLua;

  xdg.configFile."hypr/config/input.lua".text = ''
    hl.config({
        input = {
            kb_layout = "${params.input.kbLayout}",
            follow_mouse = 1,
            sensitivity = ${toString params.input.sensitivity},
            touchpad = { natural_scroll = ${if params.input.naturalScroll then "true" else "false"} },
        },
    })
  '';

  xdg.configFile."hypr/config/environment.lua".text = ''
    hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
    hl.env("XCURSOR_SIZE", "${toString params.cursorSize}")
    hl.env("HYPRCURSOR_SIZE", "${toString params.cursorSize}")
    hl.env("QT_STYLE_OVERRIDE", "kvantum")
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
  '';

  xdg.configFile."hypr/config/autostart.lua".text = ''
    local scripts = os.getenv("HOME") .. "/.config/scripts"

    hl.on("hyprland.start", function()
        hl.exec_cmd("${polkitAgent}")
        hl.exec_cmd("nm-applet")
        hl.exec_cmd("blueman-applet")
        hl.exec_cmd("qs")
        hl.exec_cmd("dunst")
        hl.exec_cmd("swww-daemon")
        hl.exec_cmd(scripts .. "/load-wallpaper.sh")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
    end)
  '';
}
