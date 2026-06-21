{ hardwareProfiles, sharedConfig, kernels, drivers }:
{
  hardwareProfile = hardwareProfiles.homePc;
  kernel = kernels."7.0.11";
  nvidiaDriver = drivers."610.43.02";
  hostname = "ddHomePC";
  timezone = "Europe/Minsk";
  stateVersion = "26.05";
  buildLabel = "linux-7.0.11-nvidia-610.43.02";
  accounts = [ sharedConfig.accounts.dd ];
}
