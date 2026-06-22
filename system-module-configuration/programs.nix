programs:
{ lib, ... }: {
  programs.wireguard.enable = lib.mkIf (programs.wireguard or false) true;

  programs.steam = lib.mkIf (programs.steam or false) {
    enable = true;
  };
}
