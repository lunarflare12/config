{
  config,
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
      hl.on("config.reloaded", apply_monitors)
    '';

  polkitAgent = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
  owStretchPluginDir = "${pkgs.hyprlandPlugins.csgo-vulkan-fix}";
  # Store copies freeze Super+X / windows.lua at the last switch. Follow the
  # git tree the same way quickshell and scripts already do.
  hyprDots = "${config.home.homeDirectory}/config/home/dots/hypr";
  linkHypr = rel: {
    source = config.lib.file.mkOutOfStoreSymlink "${hyprDots}/${rel}";
    force = true;
  };
in
{
  xdg.configFile."hypr/ow-vkfix-dir".text = owStretchPluginDir;
  xdg.configFile."hypr/hyprland.lua" = linkHypr "hyprland.lua";
  xdg.configFile."hypr/config/animations.lua" = linkHypr "config/animations.lua";
  xdg.configFile."hypr/config/decorations.lua" = linkHypr "config/decorations.lua";
  xdg.configFile."hypr/config/theme.lua" = linkHypr "config/theme.lua";
  xdg.configFile."hypr/config/layerules.lua" = linkHypr "config/layerules.lua";
  xdg.configFile."hypr/config/workspaces.lua" = linkHypr "config/workspaces.lua";
  xdg.configFile."hypr/config/windows.lua" = linkHypr "config/windows.lua";
  xdg.configFile."hypr/config/keybinds.lua" = linkHypr "config/keybinds.lua";

  home.activation.clearKeybindsBak = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    bak="${config.xdg.configHome}/hypr/config/keybinds.lua.hm.bak"
    if [ -e "$bak" ]; then
      mv "$bak" "$bak.prev"
    fi
  '';
  xdg.configFile."hypr/config/permissions.lua" = linkHypr "config/permissions.lua";

  xdg.configFile."hypr/config/programs.lua" = {
    force = true;
    text = ''
      return {
          terminal = "${params.terminal}",
          browser = "${params.browser}",
          file_manager = "${params.fileManager}",
          scripts = os.getenv("HOME") .. "/.config/scripts",
      }
    '';
  };

  xdg.configFile."hypr/config/monitors.lua" = {
    force = true;
    text = monitorLua;
  };

  xdg.configFile."hypr/config/input.lua" = {
    force = true;
    text = ''
      hl.config({
          input = {
              kb_layout = "${params.input.kbLayout}",
              follow_mouse = 1,
              sensitivity = ${toString params.input.sensitivity},
              accel_profile = "flat",
              touchpad = { natural_scroll = ${if params.input.naturalScroll then "true" else "false"} },
          },
          cursor = {
              hide_on_key_press = false,
              no_hardware_cursors = true,
              use_cpu_buffer = false,
              enable_hyprcursor = false,
              default_monitor = "DP-1",
          },
          xwayland = {
              force_zero_scaling = true,
              use_nearest_neighbor = false,
          },
      })
    '';
  };

  xdg.configFile."gamemode.ini" = {
    force = true;
    text = ''
      [custom]
      start=${config.home.homeDirectory}/.config/scripts/gamemode-start.sh
      end=${config.home.homeDirectory}/.config/scripts/gamemode-end.sh
    '';
  };

  xdg.configFile."uwsm/env-hyprland".text = ''
    export AQ_DRM_DEVICES="/dev/dri/nvidia-card"
  '';

  xdg.configFile."uwsm/env".text = ''
    export GTK_THEME=Adwaita:dark
    export GTK_APPLICATION_PREFER_DARK_THEME=1
    export QT_QPA_PLATFORMTHEME=qt6ct
    export QT_STYLE_OVERRIDE=kvantum
    export ADW_DEBUG_COLOR_SCHEME=prefer-dark
  '';

  xdg.configFile."hypr/config/environment.lua" = {
    force = true;
    text = ''
      hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
      hl.env("XCURSOR_THEME", "breeze_cursors")
      hl.env("XCURSOR_SIZE", "${toString params.cursorSize}")
      hl.env("HYPRCURSOR_SIZE", "${toString params.cursorSize}")
      hl.env("GTK_THEME", "Adwaita:dark")
      hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")
      hl.env("QT_STYLE_OVERRIDE", "kvantum")
      hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
      hl.env("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
      hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-card")
    '';
  };

  xdg.configFile."hypr/config/autostart.lua" = {
    force = true;
    text = ''
      hl.on("hyprland.start", function()
          hl.exec_cmd(os.getenv("HOME") .. "/.config/scripts/hypr-fix-safe-mode.sh")
          hl.exec_cmd("env QT_QUICK_CONTROLS_STYLE=Fusion ${polkitAgent}")
          hl.exec_cmd("hypridle")
          hl.exec_cmd(os.getenv("HOME") .. "/.config/scripts/steam-lock-shaders.sh")
          hl.exec_cmd(os.getenv("HOME") .. "/.config/scripts/qs-session-start.sh")
      end)

      hl.on("monitor.added", function()
          hl.exec_cmd(os.getenv("HOME") .. "/.config/scripts/load-wallpaper.sh")
      end)
    '';
  };

  systemd.user.services.hypr-fix-safe-mode = {
    Unit = {
      Description = "Load real Hyprland config after watchdog safe-mode";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.home.homeDirectory}/.config/scripts/hypr-fix-safe-mode.sh";
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
