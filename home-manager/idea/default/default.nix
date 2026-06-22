{ config, lib, pkgs, ... }:
let
  terminfo = "${pkgs.ncurses}/share/terminfo";
  ideaPkg = pkgs.jetbrains.idea-oss;
  ideaBin = "idea-oss";

  ideaLauncher = pkgs.writeShellScript "idea-wl" ''
    export TERM="''${TERM:-xterm-256color}"
    export COLORTERM=truecolor
    export TERMINFO="''${TERMINFO:-${terminfo}}"
    exec ${ideaPkg}/bin/${ideaBin} \
      -Dawt.toolkit.name=WLToolkit \
      -Didea.terminal.environment.variables=TERM=xterm-256color;COLORTERM=truecolor;TERMINFO=${terminfo} \
      -Djetbrains.terminal.enable.shell.integration=false \
      "$@"
  '';

  ideaLinux = pkgs.symlinkJoin {
    name = "idea-wl-${ideaPkg.version}";
    paths = [ ideaPkg ];
    postBuild = ''
      rm -f $out/bin/${ideaBin}
      ${lib.getExe' pkgs.coreutils "install"} -m0555 ${ideaLauncher} $out/bin/${ideaBin}
      ln -sf ${ideaBin} $out/bin/idea
    '';
    meta = ideaPkg.meta;
  };

  jetbrainsTerminalXml = pkgs.writeText "jetbrains-terminal-colors.xml" ''
    <application>
      <component name="TerminalOptionsProvider">
        <option name="shellIntegration" value="false" />
        <option name="envData">
          <EnvironmentVariablesData>
            <option name="PASS_PARENT_ENVS" value="true" />
            <option name="ENV_VARIABLES">
              <map>
                <entry key="TERM" value="xterm-256color" />
                <entry key="COLORTERM" value="truecolor" />
                <entry key="TERMINFO" value="${terminfo}" />
              </map>
            </option>
          </EnvironmentVariablesData>
        </option>
      </component>
    </application>
  '';

  jetbrainsConfigRoot = "${config.home.homeDirectory}/.config/JetBrains";
in {
  home.packages = [ ideaLinux ];

  home.activation.jetbrainsTerminalColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for cfg in ${lib.escapeShellArg jetbrainsConfigRoot}/IntelliJIdea*; do
      [ -d "$cfg/options" ] || continue
      run install -m0644 ${jetbrainsTerminalXml} "$cfg/options/terminal-colors.nix.xml"
    done
  '';
}
