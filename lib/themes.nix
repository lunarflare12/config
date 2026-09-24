{
  global = {

    # Active theme

    activeTheme = "macos-golden-gate";

    # Fonts

    fonts = {
      interface = {
        name = "Inter";
        package = "inter";
      };

      terminal = {
        name = "JetBrainsMono Nerd Font Mono";
        package = "nerd-fonts.jetbrains-mono";
      };

      emoji = {
        name = "Noto Color Emoji";
        package = "noto-fonts-color-emoji";
      };
    };

    # Icons

    icons = {
      name = "WhiteSur-dark";
      package = "whitesur-icon-theme";
    };

    # Cursor

    cursor = {
      name = "macOS";
      package = "apple-cursor";
      size = 24;
    };

    # UI

    ui = {

      borderWidth = 3;

      radius = 0;
      radiusSmall = 0;
      radiusLarge = 0;

      iconSize = 17;

      fontSize = 13;
      fontSizeSmall = 11;
      fontSizeLarge = 15;

      terminalOpacity = 0.78;

      # CLOCK

      clock.hour = "foreground";
    };
  };

  # THEMES

  themes = {

    # ==========================================================
    # MACOS GOLDEN GATE
    # ==========================================================

    macos-golden-gate = {

      name = "macOS Golden Gate";

      description = "Apple dark system UI";

      colors = {

        background = "#1C1C1E";

        surface = "#2C2C2E";
        surfaceHover = "#3A3A3C";

        border = "#545458";
        borderFocus = "#0A84FF";
        separator = "#38383A";

        text = "#F5F5F7";
        textSecondary = "#EBEBF5";
        textMuted = "#98989D";

        accent = "#0A84FF";
        accentHover = "#409CFF";
        accentActive = "#64D2FF";
        accentMuted = "#0A3D73";
        accentForeground = "#FFFFFF";

        success = "#30D158";
        warning = "#FFD60A";
        error = "#FF453A";
        info = "#64D2FF";

        terminalBlack = "#1C1C1E";
        terminalRed = "#FF453A";
        terminalGreen = "#30D158";
        terminalYellow = "#FFD60A";
        terminalBlue = "#0A84FF";
        terminalMagenta = "#BF5AF2";
        terminalCyan = "#64D2FF";
        terminalWhite = "#EBEBF5";

        terminalBrightBlack = "#8E8E93";
        terminalBrightRed = "#FF6961";
        terminalBrightGreen = "#30DB5B";
        terminalBrightYellow = "#FFD426";
        terminalBrightBlue = "#409CFF";
        terminalBrightMagenta = "#DA8FFF";
        terminalBrightCyan = "#70D7FF";
        terminalBrightWhite = "#F5F5F7";
      };
    };

    # ==========================================================
    # CATPPUCCIN MOCHA
    # ==========================================================

    catppuccin-mocha = {

      name = "Catppuccin Mocha";

      description = "Soft pastel dark theme";

      colors = {

        # Base
        background = "#1E1E2E";

        # Surfaces
        surface = "#313244";
        surfaceHover = "#45475A";

        # Borders
        border = "#45475A";
        borderFocus = "#CBA6F7";
        separator = "#3B3D52";

        # Text
        text = "#CDD6F4";
        textSecondary = "#BAC2DE";
        textMuted = "#9399B2";

        # Accent
        accent = "#CBA6F7";
        accentHover = "#B4BEFE";
        accentActive = "#F5C2E7";
        accentMuted = "#585B70";
        accentForeground = "#1E1E2E";

        # Semantic
        success = "#A6E3A1";
        warning = "#F9E2AF";
        error = "#F38BA8";
        info = "#89B4FA";

        # ANSI
        terminalBlack = "#45475A";
        terminalRed = "#F38BA8";
        terminalGreen = "#A6E3A1";
        terminalYellow = "#F9E2AF";
        terminalBlue = "#89B4FA";
        terminalMagenta = "#F5C2E7";
        terminalCyan = "#94E2D5";
        terminalWhite = "#BAC2DE";

        terminalBrightBlack = "#585B70";
        terminalBrightRed = "#F38BA8";
        terminalBrightGreen = "#A6E3A1";
        terminalBrightYellow = "#F9E2AF";
        terminalBrightBlue = "#89B4FA";
        terminalBrightMagenta = "#F5C2E7";
        terminalBrightCyan = "#94E2D5";
        terminalBrightWhite = "#CDD6F4";
      };
    };

    # ==========================================================
    # TOKYO NIGHT
    # ==========================================================

    tokyo-night = {

      name = "Tokyo Night";

      description = "Deep blue violet night theme";

      colors = {

        # Base
        background = "#1A1B26";

        # Surfaces
        surface = "#24283B";
        surfaceHover = "#292E42";

        # Borders
        border = "#3B4261";
        borderFocus = "#7AA2F7";
        separator = "#292E42";

        # Text
        text = "#C0CAF5";
        textSecondary = "#A9B1D6";
        textMuted = "#7982A9";

        # Accent
        accent = "#7AA2F7";
        accentHover = "#8DB0FF";
        accentActive = "#BB9AF7";
        accentMuted = "#414868";
        accentForeground = "#1A1B26";

        # Semantic
        success = "#9ECE6A";
        warning = "#E0AF68";
        error = "#F7768E";
        info = "#7DCFFF";

        # ANSI
        terminalBlack = "#414868";
        terminalRed = "#F7768E";
        terminalGreen = "#9ECE6A";
        terminalYellow = "#E0AF68";
        terminalBlue = "#7AA2F7";
        terminalMagenta = "#BB9AF7";
        terminalCyan = "#7DCFFF";
        terminalWhite = "#7982A9";

        terminalBrightBlack = "#565F89";
        terminalBrightRed = "#FF899D";
        terminalBrightGreen = "#9FE044";
        terminalBrightYellow = "#FABA4A";
        terminalBrightBlue = "#8DB0FF";
        terminalBrightMagenta = "#C7A9FF";
        terminalBrightCyan = "#A4DAFF";
        terminalBrightWhite = "#C0CAF5";
      };
    };
  };
}
