{
  repos = import ./repos.nix;
  accounts = import ./accounts.nix;
  kernels = import ./kernels.nix;
  drivers = import ./drivers.nix;
  wm = import ./wm.nix;
  initSys = import ./init-sys.nix;
}
