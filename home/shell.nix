{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ff = "fastfetch";
      ls = "eza -l --git --icons --group-directories-first";
      ll = "eza -al --git --icons --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      cd = "z";
      tmn = "tmux new -s";
      tma = "tmux attach -t";
      tmd = "tmux detach";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."starship/starship.toml".source = ./dots/starship/starship.toml;
  home.sessionVariables.STARSHIP_CONFIG = "${config.xdg.configHome}/starship/starship.toml";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./dots/tmux.conf;
  };

  home.packages = [ pkgs.fastfetch ];
}
