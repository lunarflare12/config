{
  lib,
  pkgs,
  desktopEnv,
}:

let
  inherit (desktopEnv) gtkQt;

  # Shared dark preference for host apps and isolated spaces.
  # Chromium / Electron / libadwaita need these when portals are absent.
  darkTheme = gtkQt // {
    ELECTRON_FORCE_DARK = "1";
    GTK_USE_PORTAL = "0";
    COLOR_SCHEME = "prefer-dark";
  };

  shellQuote = lib.escapeShellArg;

  exportLines =
    env:
    lib.concatStrings (
      lib.mapAttrsToList (key: value: "export ${key}=${shellQuote (toString value)}\n") env
    );

  # `-e KEY=VAL` flags for docker exec / compose overrides.
  dockerEnvArgs =
    env:
    lib.concatStringsSep " " (
      lib.mapAttrsToList (key: value: "-e ${key}=${shellQuote (toString value)}") env
    );

  # YAML fragment: KEY: VAL under a compose environment: block.
  composeEnvYaml =
    env:
    lib.concatStrings (
      lib.mapAttrsToList (key: value: "  ${key}: ${shellQuote (toString value)}\n") env
    );

  defaults = {
    # host — run a package on the host with dark + ozone flags
    # container — docker compose up (+ optional docker exec)
    kind = "host";
    package = null;
    bin = null; # override binary path; defaults to getExe package
    flags = [ ];
    unset = [
      "NIXOS_OZONE_WL"
      "ELECTRON_OZONE_PLATFORM_HINT"
    ];
    env = { }; # merged on top of darkTheme
    forceDark = true;
    platform = "wayland"; # wayland | x11 | null (skip ozone flags)
    compose = "containers/apps/compose.yml"; # relative to $HOME
    service = null; # defaults to name
    containerUser = "app";
    containerBin = null; # defaults to resolveBin
    containerArgs = [ ]; # args before ozone/flags
    startOnly = false; # true → `up -d` only (idea / spotify / telegram-2)
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
    ];
  };

  resolveBin =
    cfg:
    if cfg.bin != null then
      cfg.bin
    else if cfg.package != null then
      lib.getExe cfg.package
    else
      null;

  ozoneFlags =
    cfg:
    lib.optionals (cfg.platform == "wayland") [ "--ozone-platform=wayland" ]
    ++ lib.optionals (cfg.platform == "x11") [ "--ozone-platform=x11" ]
    ++ lib.optionals cfg.forceDark [ "--force-dark-mode" ];

  hostScript =
    cfg:
    let
      bin = resolveBin cfg;
      allFlags = ozoneFlags cfg ++ cfg.flags;
      unsetLines = lib.concatMapStrings (v: "unset ${v}\n") cfg.unset;
    in
    assert bin != null;
    ''
      ${unsetLines}${exportLines (darkTheme // cfg.env)}exec ${bin} ${lib.escapeShellArgs allFlags} "$@"
    '';

  containerScript =
    cfg:
    let
      service = if cfg.service != null then cfg.service else cfg.name;
      staticEnv =
        darkTheme
        // {
          XDG_RUNTIME_DIR = "/tmp/xdg";
        }
        // cfg.env;
      dockerArgs = dockerEnvArgs staticEnv;
      bin = if cfg.containerBin != null then cfg.containerBin else resolveBin cfg;
      args = cfg.containerArgs ++ ozoneFlags cfg ++ cfg.flags;
    in
    ''
      set -euo pipefail
      compose="''${HOME}/${cfg.compose}"
      docker compose -f "$compose" up -d --no-build ${service}
      ${lib.optionalString (!cfg.startOnly && bin != null) ''
        if [ "$#" -gt 0 ]; then
          docker exec -u ${cfg.containerUser} \
            -e WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}" \
            -e GDK_BACKEND=wayland \
            -e QT_QPA_PLATFORM=wayland \
            ${dockerArgs} \
            ${service} \
            ${bin} \
            ${lib.escapeShellArgs args} \
            "$@"
        fi
      ''}
    '';

  /*
    createSpace "discord" {
      package = pkgs.discord;
      platform = "x11";
      flags = [ "--disable-gpu" ];
    }

    createSpace "spotify" {
      kind = "container";
      startOnly = true;
    }

    createSpace "telegram-2" {
      kind = "container";
      compose = "containers/telegram/compose.yml";
      startOnly = true;
    }
  */
  createSpace =
    name: options:
    let
      cfg = defaults // options // { inherit name; };
      text =
        if cfg.kind == "container" then
          containerScript cfg
        else if cfg.kind == "host" then
          hostScript cfg
        else
          throw "createSpace ${name}: unknown kind '${cfg.kind}' (expected host|container)";
      package = pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = cfg.runtimeInputs;
        inherit text;
      };
    in
    {
      inherit name package;
      inherit (cfg) kind;
      env = darkTheme // cfg.env;
      script = text;
      composeEnvironment = darkTheme // cfg.env;
    };

  # Batch helper: mkSpaces { discord = { package = ...; }; spotify = { kind = "container"; startOnly = true; }; }
  mkSpaces = lib.mapAttrs (name: options: createSpace name options);
in
{
  inherit
    darkTheme
    exportLines
    dockerEnvArgs
    composeEnvYaml
    createSpace
    mkSpaces
    ;

  # Drop-in shell helpers for hand-written scripts under home/dots/scripts.
  spaceEnvSh =
    let
      keys = lib.attrNames darkTheme;
    in
    ''
      # Generated by lib/space.nix — source from launchers / docker exec wrappers.
      ${exportLines darkTheme}

      # Prints docker -e flags for every dark-theme variable.
      space_docker_env() {
        printf '%s' ${shellQuote (dockerEnvArgs darkTheme)}
      }

      # Eval-friendly: list of dark-theme keys, one per line.
      space_env_keys() {
        printf '%s\n' ${lib.escapeShellArgs keys}
      }
    '';
}
