{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  home.packages = with pkgs; [
    ranger
  ]
  ++ lib.optionals (!isDarwin) [
    ueberzug
  ];

  xdg.configFile."ranger/rc.conf".source =
    if isDarwin then ./rc.darwin.conf else ./rc.conf;

  xdg.desktopEntries.ranger = lib.mkIf (!isDarwin) {
    name = "Ranger";
    genericName = "File Manager";
    comment = "Console file manager";
    exec = "${lib.getExe pkgs.kitty} --class=ranger -e ranger %F";
    icon = "system-file-manager";
    categories = [
      "System"
      "FileManager"
    ];
    mimeType = [
      "inode/directory"
      "application/x-directory"
      "x-directory/normal"
    ];
  };
}
