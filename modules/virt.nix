{
  lib,
  pkgs,
  host,
  ...
}:

let
  libvirt = host.enabled "libvirt" || host.enabled "virt-manager";
in
{
  virtualisation = {
    libvirtd = {
      enable = libvirt;
      qemu.package = lib.mkIf libvirt pkgs.qemu_kvm;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };
    spiceUSBRedirection.enable = libvirt;
  };

  programs.virt-manager.enable = host.enabled "virt-manager";

  environment.systemPackages = lib.optionals libvirt [
    pkgs.virt-viewer
  ];

  systemd.services.libvirtd = lib.mkIf libvirt {
    wantedBy = lib.mkForce [ ];
  };

  networking = {
    firewall.trustedInterfaces = lib.optionals libvirt [
      "virbr0"
      "virbr1"
      "virbr2"
    ];
    networkmanager.unmanaged = lib.optionals libvirt [
      "interface-name:virbr*"
      "interface-name:vnet*"
    ];
  };
}
