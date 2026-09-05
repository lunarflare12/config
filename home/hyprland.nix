{
  lib,
  pkgs,
  params,
  ...
}:

let
  monitorLua =
    let
      applyBody = lib.concatMapStrings (
        monitor:
        let
          output = ''output = "${monitor.output or ""}", '';
          transform = lib.optionalString (monitor ? transform) ''transform = ${toString monitor.transform}, '';
          bitdepth = lib.optionalString (monitor ? bitdepth) ''bitdepth = ${toString monitor.bitdepth}, '';
        in
        ''
            hl.monitor({ ${output}mode = "${monitor.mode}", position = "${monitor.position}", scale = ${toString monitor.scale}, ${bitdepth}${transform}})
        ''
      ) params.monitors;
    in
    ''
      local function apply_monitors()
      ${applyBody}end
      apply_monitors()
      hl.on("monitor.added", apply_monitors)
      hl.on("hyprland.start", apply_monitors)
      hl.on("config.reloaded", apply_monitors)
    '';

  polkitAgent = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
in
{
  xdg.configFile."hypr/hyprland.lua".source = ./dots/hypr/hyprland.lua;
  xdg.configFile."hypr/config/animations.lua".source = ./dots/hypr/config/animations.lua;
  xdg.configFile."hypr/config/decorations.lua".source = ./dots/hypr/config/decorations.lua;
  xdg.configFile."hypr/config/theme.lua".source = ./dots/hypr/config/theme.lua;
  xdg.configFile."hypr/config/layerules.lua".source = ./dots/hypr/config/layerules.lua;
  xdg.configFile."hypr/config/windows.lua".source = ./dots/hypr/config/windows.lua;
  xdg.configFile."hypr/config/keybinds.lua".source = ./dots/hypr/config/keybinds.lua;
  xdg.configFile."hypr/config/permissions.lua".source = ./dots/hypr/config/permissions.lua;

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
        cursor = {
            hide_on_key_press = false,
            no_hardware_cursors = 0,
            use_cpu_buffer = false,
            enable_hyprcursor = false,
        },
        xwayland = {
            force_zero_scaling = true,
            use_nearest_neighbor = false,
        },
    })
  '';

  xdg.configFile."uwsm/env-hyprland".text = ''
    export AQ_DRM_DEVICES="/dev/dri/card1"
  '';

  xdg.configFile."hypr/config/environment.lua".text = ''
    hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
    hl.env("XCURSOR_THEME", "breeze_cursors")
    hl.env("XCURSOR_SIZE", "${toString params.cursorSize}")
    hl.env("HYPRCURSOR_SIZE", "${toString params.cursorSize}")
    hl.env("QT_STYLE_OVERRIDE", "kvantum")
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
    hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
  '';

  xdg.configFile."hypr/config/autostart.lua".text = ''
    hl.on("hyprland.start", function()
        hl.exec_cmd("${polkitAgent}")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("nm-applet")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
    end)

    hl.on("monitor.added", function()
        hl.exec_cmd(os.getenv("HOME") .. "/.config/scripts/load-wallpaper.sh")
    end)
  '';
}
