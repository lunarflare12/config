{ config, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      general.import = [ "${config.xdg.configHome}/alacritty/theme.toml" ];
      font.normal.family = "JetBrainsMono Nerd Font";
      font.size = 14;
      window.padding = {
        x = 8;
        y = 8;
      };
    };
  };

  xdg.configFile."alacritty/themes/dark.toml".text = ''
    [colors.primary]
    foreground = "#F1DBC2"
    background = "#352B2D"

    [colors.cursor]
    text = "#352B2D"
    cursor = "#F1DBC2"

    [colors.selection]
    text = "#352B2D"
    background = "#CCB7A0"

    [colors.normal]
    black = "#AA9D8A"
    red = "#CCB7A0"
    green = "#AA9D8A"
    yellow = "#DFC8B1"
    blue = "#DFC8B1"
    magenta = "#908A7B"
    cyan = "#DFC8B1"
    white = "#F1DBC2"

    [colors.bright]
    black = "#AA9D8A"
    red = "#F1DBC2"
    green = "#CCB7A0"
    yellow = "#F1DBC2"
    blue = "#AA9D8A"
    magenta = "#DFC8B1"
    cyan = "#F1DBC2"
    white = "#F1DBC2"
  '';

  xdg.configFile."alacritty/themes/light.toml".text = ''
    [colors.primary]
    foreground = "#352B2D"
    background = "#F1DBC2"

    [colors.cursor]
    text = "#F1DBC2"
    cursor = "#352B2D"

    [colors.selection]
    text = "#F1DBC2"
    background = "#4B3D43"

    [colors.normal]
    black = "#625458"
    red = "#4B3D43"
    green = "#625458"
    yellow = "#44373A"
    blue = "#625458"
    magenta = "#857974"
    cyan = "#625458"
    white = "#352B2D"

    [colors.bright]
    black = "#44373A"
    red = "#352B2D"
    green = "#4B3D43"
    yellow = "#352B2D"
    blue = "#625458"
    magenta = "#44373A"
    cyan = "#44373A"
    white = "#352B2D"
  '';

  home.activation.alacrittyTheme = config.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/alacritty"
    if [ ! -e "${config.xdg.configHome}/alacritty/theme.toml" ]; then
      ln -sfn "${config.xdg.configHome}/alacritty/themes/dark.toml" "${config.xdg.configHome}/alacritty/theme.toml"
    fi
  '';
}
