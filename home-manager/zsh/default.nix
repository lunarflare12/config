{
  config,
  lib,
  pkgs,
  ...
}:
let
  zshDir = "${config.home.homeDirectory}/.config/zsh";
  isDarwin = pkgs.stdenv.isDarwin;

  lsColors = pkgs.runCommandLocal "hm-ls-colors" {
    nativeBuildInputs = [ pkgs.vivid ];
  } ''
    vivid generate molokai > $out
  '';
in
{
  programs.zsh = {
    enable = true;
    dotDir = zshDir;

    history = {
      path = "${zshDir}/history";
      size = 50000;
      save = 50000;
      append = true;
      extended = true;
      ignorePatterns = [
        "rm *"
        "pkill *"
        "mkpasswd *"
        "* --password*"
      ];
    };

    autosuggestion.enable = true;
    autosuggestion.highlight = "fg=8";

    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "main"
        "brackets"
        "line"
      ];
    };

    historySubstringSearch.enable = true;

    enableCompletion = true;
    defaultKeymap = "emacs";

    setOptions = [
      "AUTO_CD"
      "HIST_VERIFY"
      "INTERACTIVE_COMMENTS"
      "NO_BEEP"
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LESS = "-R -F -X";
      COLORTERM = "truecolor";
      CLICOLOR = "1";
      LS_COLORS = builtins.readFile lsColors;
    };

    shellAliases =
      {
        ll = if isDarwin then "ls -lAhG" else "ls -lAh --color=auto";
        la = if isDarwin then "ls -lahG" else "ls -lah --color=auto";
        l = if isDarwin then "ls -lahG" else "ls -lah --color=auto";
        ".." = "cd ..";
        "..." = "cd ../..";
        grep = if isDarwin then "grep --color=auto" else "grep --color=auto";
        diff = "diff --color=auto";
      }
      // lib.optionalAttrs isDarwin {
        ls = "ls -G";
        ip = "ip";
      }
      // lib.optionalAttrs (!isDarwin) {
        ls = "ls --color=auto";
        ip = "ip -color=auto";
      };

    initContent = lib.mkMerge [
      (lib.mkOrder 100 (builtins.readFile ./nix-env.sh))
      (lib.mkOrder 505 ''
        if [[ -d /run/wrappers/bin ]]; then
          export PATH="/run/wrappers/bin:$PATH"
        fi

        export ZSH_CACHE_DIR="${zshDir}/cache"
        export XDG_CACHE_HOME="$ZSH_CACHE_DIR"
        export XDG_STATE_HOME="${zshDir}/state"
        export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-$HOST-$SHORT_HOST-$ZSH_VERSION"
        export LESSHISTFILE="${zshDir}/lesshst"
        export POWERLEVEL9K_CONFIG_FILE="${zshDir}/p10k.zsh"
        mkdir -p "$ZSH_CACHE_DIR" "$XDG_STATE_HOME" "${zshDir}/sessions"

        if [[ -n "''${TERMINAL_EMULATOR:-}" ]] || [[ -n "''${INTELLIJ_TERMINAL:-}" ]] || [[ -n "''${IDEA_INITIAL_DIRECTORY:-}" ]]; then
          [[ "''${TERM:-}" == dumb || -z "''${TERM:-}" ]] && export TERM=xterm-256color
          export COLORTERM=truecolor
          if [[ -z "''${TERMINFO:-}" && -d ${pkgs.ncurses}/share/terminfo ]]; then
            export TERMINFO=${pkgs.ncurses}/share/terminfo
          fi
        fi

        if [[ -z "''${LS_COLORS:-}" ]] && command -v dircolors &>/dev/null; then
          eval "$(dircolors -b)"
        fi

        export MANROFFOPT="-c"
        export LESS_TERMCAP_mb=$'\e[1;31m'
        export LESS_TERMCAP_md=$'\e[1;36m'
        export LESS_TERMCAP_me=$'\e[0m'
        export LESS_TERMCAP_se=$'\e[0m'
        export LESS_TERMCAP_so=$'\e[01;33m'
        export LESS_TERMCAP_ue=$'\e[0m'
        export LESS_TERMCAP_us=$'\e[1;4;32m'
      '')
      (lib.mkOrder 550 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '')
      (lib.mkOrder 1000 ''
        [[ -f "$POWERLEVEL9K_CONFIG_FILE" ]] && source "$POWERLEVEL9K_CONFIG_FILE"
      '')
    ];
  };

  xdg.configFile."zsh/p10k.zsh".source = ./p10k.zsh;

  # macOS login shells read .zprofile before HM .zshrc — keep nix on PATH after reboot
  home.file.".zprofile" = lib.mkIf isDarwin {
    text = ''
      # home-manager: nix PATH (do not remove)
      ${builtins.readFile ./nix-env.sh}
    '';
    force = true;
  };

  home.packages = with pkgs; [
    zsh-powerlevel10k
    vivid
  ];
}
