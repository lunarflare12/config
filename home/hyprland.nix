{
  config,
  lib,
  pkgs,
  params,
  desktopEnv,
  ...
}:

let
  env = desktopEnv;
  repoRoot = "${config.home.homeDirectory}/${params.repo}";
  hyprDots = "${repoRoot}/home/dots/hypr";
  linkHypr = rel: {
    source = config.lib.file.mkOutOfStoreSymlink "${hyprDots}/${rel}";
    force = true;
  };
  hyprLinks = [
    "hyprland.lua"
    "config/animations.lua"
    "config/cursor-env.lua"
    "config/decorations.lua"
    "config/theme.lua"
    "config/layerules.lua"
    "config/workspaces.lua"
    "config/windows.lua"
    "config/keybinds.lua"
    "config/permissions.lua"
  ];

  monitorLua =
    let
      dp = lib.findFirst (m: (m.output or "") == "DP-1") null params.monitors;
      hdmi = lib.findFirst (m: (m.output or "") == "HDMI-A-1") null params.monitors;
      fmt =
        monitor:
        let
          transform = lib.optionalString (monitor ? transform) "transform = ${toString monitor.transform}, ";
          bitdepth = lib.optionalString (monitor ? bitdepth) "bitdepth = ${toString monitor.bitdepth}, ";
        in
        ''hl.monitor({ output = "${monitor.output}", mode = "${monitor.mode}", position = "${monitor.position}", scale = ${toString monitor.scale}, ${bitdepth}${transform}})'';
    in
    ''
      local function apply_monitors()
        ${if dp != null then fmt dp else ""}
        ${if hdmi != null then fmt hdmi else ""}
      end
      apply_monitors()
      hl.on("monitor.added", apply_monitors)
      hl.on("config.reloaded", apply_monitors)
    '';

  polkitAgent = pkgs.writeShellScript "hyprpolkitagent-wrap" ''
    export QT_QUICK_CONTROLS_STYLE=Fusion
    unset QT_STYLE_OVERRIDE
    exec ${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent "$@"
  '';
  owStretchPluginDir = "${pkgs.hyprlandPlugins.csgo-vulkan-fix}";
  scripts = "${config.home.homeDirectory}/.config/scripts";
  luaEnv =
    lib.concatStrings (
      lib.mapAttrsToList
        (key: value: ''
          hl.env("${key}", "${value}")
        '')
        (
          env.gtkQt
          // {
            XCURSOR_THEME = "macOS";
            XCURSOR_SIZE = toString params.cursorSize;
            HYPRCURSOR_SIZE = toString params.cursorSize;
            AQ_DRM_DEVICES = env.nvidiaGl.AQ_DRM_DEVICES;
          }
        )
    )
    + ''
      hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
    '';
  uwsmEnv = lib.concatStrings (lib.mapAttrsToList (key: value: "export ${key}=${value}\n") env.gtkQt);
in
{
  xdg.configFile = lib.mkMerge [
    (lib.listToAttrs (
      map (rel: {
        name = "hypr/${rel}";
        value = linkHypr rel;
      }) hyprLinks
    ))
    {
      "hypr/ow-vkfix-dir".text = owStretchPluginDir;

      "hypr/config/programs.lua" = {
        force = true;
        text = ''
          return {
              terminal = "${params.terminal}",
              browser = "${
                if params.browser == "google-chrome" then
                  "${config.home.homeDirectory}/.config/scripts/google-chrome.sh"
                else
                  params.browser
              }",
              file_manager = "${config.home.homeDirectory}/.config/scripts/finder.sh",
              scripts = os.getenv("HOME") .. "/.config/scripts",
          }
        '';
      };

      "hypr/config/monitors.lua" = {
        force = true;
        text = monitorLua;
      };

      "hypr/config/input.lua" = {
        force = true;
        text = ''
          hl.config({
              input = {
                  kb_layout = "${params.input.kbLayout}",
                  follow_mouse = 1,
                  mouse_refocus = false,
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

      "uwsm/env-hyprland".text = ''
        export AQ_DRM_DEVICES="${env.nvidiaGl.AQ_DRM_DEVICES}"
      '';

      "uwsm/env".text = uwsmEnv;

      "hypr/config/environment.lua" = {
        force = true;
        text = luaEnv;
      };

      "hypr/config/autostart.lua" = {
        force = true;
        text = ''
          hl.on("hyprland.start", function()
              hl.exec_cmd("${scripts}/hypr-fix-safe-mode.sh")
              hl.exec_cmd("hypridle")
              hl.exec_cmd("${scripts}/steam-lock-shaders.sh")
              hl.exec_cmd("${scripts}/cap-fossilize.sh")
              hl.exec_cmd("${scripts}/qs-session-start.sh")
          end)

          hl.on("monitor.added", function()
              hl.exec_cmd("${scripts}/load-wallpaper.sh")
          end)
        '';
      };
    }
  ];

  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "Hyprland Polkit authentication agent";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${polkitAgent}";
      Restart = "on-failure";
      RestartSec = "1";
      UnsetEnvironment = [ "QT_STYLE_OVERRIDE" ];
      Environment = [ "QT_QUICK_CONTROLS_STYLE=Fusion" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
