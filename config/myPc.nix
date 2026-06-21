{ config, params }: {
  hardware = config.myHomePC;
  hostName = "ddHomePC";
  timeZone = "Europe/Minsk";
  stateVersion = "26.05";
  snapshot = "ebal-ego-v-rot";
  users = [ params.users.dd ];
}
