kernel: { pkgs, ... }: {
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.${kernel.attr};
}
