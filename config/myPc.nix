{ config, params }: {
  hardware = config.myHomePC;
  hostName = "ddHomePC";
  timeZone = "Europe/Minsk";
  stateVersion = "26.05";
  users = [ params.users.dd ];
}
