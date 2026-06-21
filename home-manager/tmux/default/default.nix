{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      gruvbox
      resurrect
      continuum
    ];
    extraConfig = builtins.readFile ./tmux.conf;
  };
}
