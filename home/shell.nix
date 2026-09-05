{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "kubectl"
        "docker"
        "aws"
      ];
    };

    shellAliases = {
      ff = "fastfetch";
      ls = "eza -l --git --icons --group-directories-first";
      ll = "eza -al --git --icons --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      cd = "z";
      tmn = "tmux new -s";
      tma = "tmux attach -t";
      tmd = "tmux detach";
      r = "ranger";
      k = "kubectl";
    };

    initContent = ''
      # k9s completion
      if command -v k9s >/dev/null 2>&1; then
        source <(k9s completion zsh)
      fi

      # nix-specific completions
      if [ -f ${pkgs.nix-zsh-completions}/share/nix-zsh-completions/nix-zsh-completions.zsh ]; then
        source ${pkgs.nix-zsh-completions}/share/nix-zsh-completions/nix-zsh-completions.zsh
      fi
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--info=inline"
    ];
  };

  programs.ranger = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."starship.toml".source = ./dots/starship/starship.toml;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./dots/tmux.conf;
  };

  home.packages = with pkgs; [
    fastfetch
    nix-zsh-completions
  ];
}
