{ lib, params, ... }:

let
  vms = params.vms or [ ];
  libvirt = lib.elem "libvirt" vms || lib.elem "virt-manager" vms;
in
{
  virtualisation.libvirtd.enable = libvirt;
  virtualisation.spiceUSBRedirection.enable = libvirt;
  programs.virt-manager.enable = lib.elem "virt-manager" vms;

  users.users = lib.mkIf libvirt (
    lib.mapAttrs (_: _: {
      extraGroups = [
        "libvirtd"
        "kvm"
      ];
    }) params.users
  );
}
