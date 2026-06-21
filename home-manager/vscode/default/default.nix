{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  continueSchema =
    "file://${homeDir}/.vscode/extensions/continue.continue-1.2.22-darwin-arm64/config-yaml-schema.json";
in
lib.mkIf pkgs.stdenv.isDarwin {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      userSettings = {
        "terminal.integrated.fontFamily" = "MesloLGS NF";
        "redhat.telemetry.enabled" = false;
        "editor.tabSize" = 2;
        "extensions.ignoreRecommendations" = true;
        "workbench.startupEditor" = "none";
        "window.restoreWindows" = "all";
        "explorer.confirmDelete" = false;
        "terminal.integrated.defaultLocation" = "editor";
        "go.toolsManagement.autoUpdate" = true;
        "chat.viewSessions.orientation" = "stacked";
        "http.systemCertificatesNode" = true;
        "yaml.schemas" = {
          "${continueSchema}" = [
            ".continue/**/*.yaml"
          ];
        };
        "workbench.openInAgents.enabled" = false;
        "workbench.browser.showInTitleBar" = false;
        "workbench.layoutControl.enabled" = false;
        "workbench.navigationControl.enabled" = false;
        "workbench.editor.enablePreview" = false;
        "workbench.activityBar.location" = "hidden";
        "workbench.iconTheme" = "icons";
        "workbench.colorTheme" = "Theme Darker";
        "terminal.integrated.commandsToSkipShell" = [
          "kilo-code.new.agentManagerOpen"
          "kilo-code.new.agentManager.showTerminal"
          "kilo-code.new.agentManager.runScript"
        ];
        "editor.fontSize" = 14;
        "kilo-code.new.showTaskTimeline" = false;
        "breadcrumbs.enabled" = false;
        "workbench.sideBar.location" = "right";
        "files.autoSave" = "afterDelay";
        "workbench.tips.enabled" = false;
        "workbench.tree.indent" = 12;
        "chat.fontSize" = 12;
        "scm.inputFontSize" = 12;
        "window.density.editorTabHeight" = "compact";
        "git.blame.editorDecoration.enabled" = true;
        "editor.codeLens" = false;
        "editor.glyphMargin" = false;
        "git.blame.editorDecoration.template" = "\${authorName} • \${authorDateAgo}";
        "scm.diffDecorationsGutterWidth" = 5;
        "scm.diffDecorationsGutterPattern" = {
          modified = false;
        };
        "explorer.decorations.badges" = false;
        "terminal.integrated.shellIntegration.decorationsEnabled" = "never";
        "terminal.integrated.cursorStyle" = "line";
        "scm.countBadge" = "focused";
        "editor.minimap.renderCharacters" = false;
        "terminal.integrated.initialHint" = false;
        "terminal.integrated.tabs.enabled" = false;
        "kilo-code.new.autocomplete.enableAutoTrigger" = false;
        "kilo-code.new.autoApprove.enabled" = true;
        "workbench.statusBar.visible" = false;
        "editor.minimap.enabled" = false;
        "problems.decorations.enabled" = false;
        "helm-intellisense.lintFileOnSave" = false;
        "window.commandCenter" = false;
      };
    };
  };

  home.packages = with pkgs; [
    nerd-fonts.meslo-lg
  ];
}
