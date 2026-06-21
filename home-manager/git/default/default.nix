{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      merge.ff = false;
      pull.ff = false;
    };
  };

  home.file.".gitconfig".source = config.xdg.configFile."git/config".source;
}
