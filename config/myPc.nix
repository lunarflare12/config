{ config, params }: {
  hardware = config.myHomePC;
  hostName = "ddHomePC";
  timeZone = "Europe/Minsk";
  stateVersion = "26.05";
  snapshot = "ЕБАЛ Я ЭТО В РОТ";
  users = [ params.users.dd ];
}
