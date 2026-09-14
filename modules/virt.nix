{ lib, pkgs, params, ... }:

let
  vms = params.vms or [ ];
  libvirt = lib.elem "libvirt" vms || lib.elem "virt-manager" vms;
in
{
  virtualisation.libvirtd = {
    enable = libvirt;
    qemu.package = lib.mkIf libvirt pkgs.qemu_kvm;
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  virtualisation.spiceUSBRedirection.enable = libvirt;
  programs.virt-manager.enable = lib.elem "virt-manager" vms;

  # Socket-activate: all guests are off, keep virbr0/dnsmasq from sitting idle.
  systemd.services.libvirtd = lib.mkIf libvirt {
    wantedBy = lib.mkForce [ ];
  };

  networking.firewall.trustedInterfaces = lib.optionals libvirt [
    "virbr0"
    "virbr1"
    "virbr2"
  ];
  networking.networkmanager.unmanaged = lib.optionals libvirt [
    "interface-name:virbr*"
    "interface-name:vnet*"
  ];

  environment.variables = lib.mkIf libvirt {
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };

  users.users = lib.mkIf libvirt (
    lib.mapAttrs (_: _: {
      extraGroups = [
        "libvirtd"
        "kvm"
      ];
    }) params.users
  );
}
