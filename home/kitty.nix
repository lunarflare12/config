{ ... }:

{
  programs.kitty.enable = true;

  xdg.configFile."kitty/kitty.conf" = {
    source = ./kitty/config/kitty.conf;
    force = true;
  };
}
