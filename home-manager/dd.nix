{ stateVersion, ... }: {
  home.stateVersion = stateVersion;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
  };
}
