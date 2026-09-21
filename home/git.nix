{ config, params, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = params.git.userName;
        email = params.git.userEmail;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      push.autoSetupRemote = true;
      core.editor = "nvim";
      color.ui = "auto";
      diff.algorithm = "histogram";
      merge.conflictstyle = "zdiff3";
    };
  };

  home.file.".gitconfig".source = config.xdg.configFile."git/config".source;
}
