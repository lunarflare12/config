{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
      size = 13;
    };

    settings = {
      bold_font = "JetBrainsMono Nerd Font Mono";
      italic_font = "JetBrainsMono Nerd Font Mono";
      bold_italic_font = "JetBrainsMono Nerd Font Mono";
      window_padding_width = 8;
      background_opacity = "0.85";
      dynamic_background_opacity = true;
      background_blur = 32;
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      cursor_shape = "beam";
      cursor_blink_interval = 0;
      scrollback_lines = 10000;
      mouse_hide_wait = "3.0";
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      tab_bar_min_tabs = 2;
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      shell_integration = "no-rc";
      allow_hyperlinks = "yes";
      allow_remote_control = "socket-only";

      foreground = "#cbccc6";
      background = "#1f2430";
      selection_foreground = "#1f2430";
      selection_background = "#f28779";
      cursor = "#ffcc66";
      cursor_text_color = "#1f2430";
      url_color = "#73d0ff";

      color0 = "#212733";
      color8 = "#686868";
      color1 = "#f08778";
      color9 = "#f58c7d";
      color2 = "#53bf97";
      color10 = "#58c49c";
      color3 = "#fdcc60";
      color11 = "#ffd165";
      color4 = "#60b8d6";
      color12 = "#65bddb";
      color5 = "#ec7171";
      color13 = "#f17676";
      color6 = "#98e6ca";
      color14 = "#9debcf";
      color7 = "#fafafa";
      color15 = "#ffffff";

      active_tab_background = "#1f2430";
      active_tab_foreground = "#cbccc6";
      inactive_tab_background = "#212733";
      inactive_tab_foreground = "#686868";
      active_border_color = "#a37acc";
      inactive_border_color = "#212733";
    };

    keybindings = {
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+c" = "copy_and_clear_or_interrupt";
      "ctrl+v" = "paste_from_clipboard";
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_window";
      "ctrl+shift+l" = "next_tab";
      "ctrl+shift+h" = "previous_tab";
      "ctrl+shift+equal" = "change_font_size all +1.0";
      "ctrl+shift+minus" = "change_font_size all -1.0";
      "ctrl+shift+0" = "change_font_size all 0";
    };
  };
}
