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
    "config/liixini-shaders.lua"
    "config/keybinds.lua"
    "config/permissions.lua"
    "config/monitor-pin.lua"
  ];
  windowShadePluginDir = "${pkgs.hyprlandPlugins.hypr-window-shade}";

  monitorLua =
    let
      # NVIDIA renames DP-1↔DP-4 and HDMI-A-1↔HDMI-A-2 across boots.
      # Emit every alias for the configured panel so either name pins.
      expandOutput =
        output:
        {
          "DP-1" = [
            "DP-1"
            "DP-4"
          ];
          "DP-4" = [
            "DP-4"
            "DP-1"
          ];
          "HDMI-A-1" = [
            "HDMI-A-1"
            "HDMI-A-2"
          ];
          "HDMI-A-2" = [
            "HDMI-A-2"
            "HDMI-A-1"
          ];
        }
        .${output} or [ output ];
      dp = lib.findFirst (
        m: (m.output or "") == "DP-4" || (m.output or "") == "DP-1"
      ) null params.monitors;
      hdmi = lib.findFirst (
        m: (m.output or "") == "HDMI-A-2" || (m.output or "") == "HDMI-A-1"
      ) null params.monitors;
      fmt =
        monitor: output:
        let
          transform = lib.optionalString (monitor ? transform) "transform = ${toString monitor.transform}, ";
          bitdepth = lib.optionalString (monitor ? bitdepth) "bitdepth = ${toString monitor.bitdepth}, ";
        in
        ''hl.monitor({ output = "${output}", mode = "${monitor.mode}", position = "${monitor.position}", scale = ${toString monitor.scale}, ${bitdepth}${transform}})'';
      fmtAll = monitor: lib.concatMapStringsSep "\n        " (fmt monitor) (expandOutput monitor.output);
    in
    ''
      local function apply_monitors()
        ${if dp != null then fmtAll dp else ""}
        ${if hdmi != null then fmtAll hdmi else ""}
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
  aurora = lib.getExe pkgs.aurora-helpers;
  # HM as a NixOS module installs here, not ~/.nix-profile (that tree has no finder).
  profileBin = "${config.home.profileDirectory}/bin";
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
      "hypr/config/programs.lua" = {
        force = true;
        text = ''
          return {
              terminal = "${params.terminal}",
              browser = "${
                if params.browser == "google-chrome" then "${profileBin}/google-chrome" else params.browser
              }",
              file_manager = "${profileBin}/finder",
              aurora = "${aurora}",
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
                  use_nearest_neighbor = true,
              },
          })
        '';
      };

      "uwsm/env-hyprland".text = ''
        export AQ_DRM_DEVICES="${env.nvidiaGl.AQ_DRM_DEVICES}"
      '';

      "uwsm/env".text = uwsmEnv;

      "hypr/hypr-window-shade-dir".text = windowShadePluginDir;

      "hypr/shaders/liixini" = {
        source = config.lib.file.mkOutOfStoreSymlink "${hyprDots}/shaders/liixini";
        force = true;
      };

      "hypr/config/environment.lua" = {
        force = true;
        text = luaEnv;
      };

      "hypr/config/autostart.lua" = {
        force = true;
        text = ''
          hl.on("hyprland.start", function()
              hl.exec_cmd("${aurora} hypr-fix")
              hl.exec_cmd("hypridle")
              hl.exec_cmd("${aurora} steam-lock")
              hl.exec_cmd("${aurora} fossilize")
              hl.exec_cmd("${aurora} shade load")
              hl.exec_cmd("${aurora} session")
          end)

          hl.on("monitor.added", function()
              hl.exec_cmd("${aurora} wallpaper load")
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
