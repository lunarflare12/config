{
  global = {

    # Active theme

    activeTheme = "brain-shell";

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

      borderWidth = 2;

      radius = 0;
      radiusSmall = 0;
      radiusLarge = 0;

      iconSize = 16;

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

    burg = {
      name = "Burg";
      description = "CARTO Burg palette";
      swatches = [ "#FFC6C4" "#F4A3A8" "#E38191" "#CC607D" "#AD466C" "#8B3058" "#672044" ];
      colors = {
        background = "#41182E";
        surface = "#6F2748";
        surfaceHover = "#93395D";
        border = "#953C5E";
        borderFocus = "#F4A3A8";
        separator = "#622341";
        text = "#FFC6C4";
        textSecondary = "#F4A3A8";
        textMuted = "#CE7C92";
        accent = "#E38191";
        accentHover = "#F4A3A8";
        accentActive = "#FFC6C4";
        accentMuted = "#8B3058";
        accentForeground = "#41182E";
        success = "#F4A3A8";
        warning = "#E38191";
        error = "#AD466C";
        info = "#F4A3A8";
        terminalBlack = "#41182E";
        terminalRed = "#AD466C";
        terminalGreen = "#E38191";
        terminalYellow = "#F4A3A8";
        terminalBlue = "#CC607D";
        terminalMagenta = "#8B3058";
        terminalCyan = "#E38191";
        terminalWhite = "#FFC6C4";
        terminalBrightBlack = "#8B3058";
        terminalBrightRed = "#CC607D";
        terminalBrightGreen = "#F4A3A8";
        terminalBrightYellow = "#FFC6C4";
        terminalBrightBlue = "#E38191";
        terminalBrightMagenta = "#AD466C";
        terminalBrightCyan = "#F4A3A8";
        terminalBrightWhite = "#F4F4F5";
      };
    };

    emrld = {
      name = "Emrld";
      description = "CARTO Emrld palette";
      swatches = [ "#D3F2A3" "#97E196" "#6CC08B" "#4C9B82" "#217A79" "#105965" "#074050" ];
      colors = {
        background = "#092B35";
        surface = "#0D4853";
        surfaceHover = "#196569";
        border = "#1C696A";
        borderFocus = "#97E196";
        separator = "#0C404B";
        text = "#D3F2A3";
        textSecondary = "#97E196";
        textMuted = "#6EA996";
        accent = "#6CC08B";
        accentHover = "#97E196";
        accentActive = "#D3F2A3";
        accentMuted = "#105965";
        accentForeground = "#092B35";
        success = "#97E196";
        warning = "#6CC08B";
        error = "#217A79";
        info = "#97E196";
        terminalBlack = "#092B35";
        terminalRed = "#217A79";
        terminalGreen = "#6CC08B";
        terminalYellow = "#97E196";
        terminalBlue = "#4C9B82";
        terminalMagenta = "#105965";
        terminalCyan = "#6CC08B";
        terminalWhite = "#D3F2A3";
        terminalBrightBlack = "#105965";
        terminalBrightRed = "#4C9B82";
        terminalBrightGreen = "#97E196";
        terminalBrightYellow = "#D3F2A3";
        terminalBrightBlue = "#6CC08B";
        terminalBrightMagenta = "#217A79";
        terminalBrightCyan = "#97E196";
        terminalBrightWhite = "#F4F4F5";
      };
    };

    brain-shell = {
      name = "Brain Shell";
      description = "Teal Material frame from Brain Shell";
      swatches = [ "#F3FBFA" "#D7F4EF" "#A6E4DC" "#5EBEB6" "#2F8D97" "#1E4A4E" "#142022" ];
      colors = {
        accent = "#A6D0F7";
        accentActive = "#94E2D5";
        accentForeground = "#1A282A";
        accentHover = "#C4E2FB";
        accentMuted = "#2F8D97";
        background = "#1A282A";
        border = "#2F8D97";
        borderFocus = "#A6D0F7";
        error = "#FA6B94";
        info = "#A6D0F7";
        separator = "#2A3C3E";
        success = "#94E2D5";
        surface = "#243538";
        surfaceHover = "#2D4244";
        terminalBlack = "#1A282A";
        terminalBlue = "#A6D0F7";
        terminalBrightBlack = "#4A5C5E";
        terminalBrightBlue = "#C4E2FB";
        terminalBrightCyan = "#4AA8B0";
        terminalBrightGreen = "#B4F0E4";
        terminalBrightMagenta = "#DAF0FF";
        terminalBrightRed = "#FF89A8";
        terminalBrightWhite = "#F2F3F7";
        terminalBrightYellow = "#FFE08A";
        terminalCyan = "#2F8D97";
        terminalGreen = "#94E2D5";
        terminalMagenta = "#C4E2FB";
        terminalRed = "#FA6B94";
        terminalWhite = "#CDD6F4";
        terminalYellow = "#F9E2AF";
        text = "#CDD6F4";
        textMuted = "#7AA8A0";
        textSecondary = "#94E2D5";
        warning = "#F9E2AF";
      };
    };

    sunset = {
      name = "Sunset";
      description = "CARTO Sunset palette";
      swatches = [ "#F3E79B" "#FAC484" "#F8A07E" "#EB7F86" "#CE6693" "#A059A0" "#5C53A5" ];
      colors = {
        background = "#22213A";
        surface = "#704479";
        surfaceHover = "#A75888";
        border = "#A8577F";
        borderFocus = "#FAC484";
        separator = "#5B3A68";
        text = "#F3E79B";
        textSecondary = "#FAC484";
        textMuted = "#E59499";
        accent = "#F8A07E";
        accentHover = "#FAC484";
        accentActive = "#F3E79B";
        accentMuted = "#A059A0";
        accentForeground = "#22213A";
        success = "#FAC484";
        warning = "#F8A07E";
        error = "#CE6693";
        info = "#FAC484";
        terminalBlack = "#22213A";
        terminalRed = "#CE6693";
        terminalGreen = "#F8A07E";
        terminalYellow = "#FAC484";
        terminalBlue = "#EB7F86";
        terminalMagenta = "#A059A0";
        terminalCyan = "#F8A07E";
        terminalWhite = "#F3E79B";
        terminalBrightBlack = "#A059A0";
        terminalBrightRed = "#EB7F86";
        terminalBrightGreen = "#FAC484";
        terminalBrightYellow = "#F3E79B";
        terminalBrightBlue = "#F8A07E";
        terminalBrightMagenta = "#CE6693";
        terminalBrightCyan = "#FAC484";
        terminalBrightWhite = "#F4F4F5";
      };
    };

    tokyo-night = {
      name = "Tokyo Night";
      description = "Deep blue violet night theme";
      swatches = [ "#E4E9FF" "#B7C3F3" "#7AA2F7" "#565F89" "#3B4261" "#24283B" "#1A1B26" ];
      colors = {
        accent = "#7AA2F7";
        accentActive = "#BB9AF7";
        accentForeground = "#1A1B26";
        accentHover = "#8DB0FF";
        accentMuted = "#414868";
        background = "#1A1B26";
        border = "#3B4261";
        borderFocus = "#7AA2F7";
        error = "#F7768E";
        info = "#7DCFFF";
        separator = "#292E42";
        success = "#9ECE6A";
        surface = "#24283B";
        surfaceHover = "#292E42";
        terminalBlack = "#414868";
        terminalBlue = "#7AA2F7";
        terminalBrightBlack = "#565F89";
        terminalBrightBlue = "#8DB0FF";
        terminalBrightCyan = "#A4DAFF";
        terminalBrightGreen = "#9FE044";
        terminalBrightMagenta = "#C7A9FF";
        terminalBrightRed = "#FF899D";
        terminalBrightWhite = "#C0CAF5";
        terminalBrightYellow = "#FABA4A";
        terminalCyan = "#7DCFFF";
        terminalGreen = "#9ECE6A";
        terminalMagenta = "#BB9AF7";
        terminalRed = "#F7768E";
        terminalWhite = "#7982A9";
        terminalYellow = "#E0AF68";
        text = "#C0CAF5";
        textMuted = "#7982A9";
        textSecondary = "#A9B1D6";
        warning = "#E0AF68";
      };
    };
  };
}
