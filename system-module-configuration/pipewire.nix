audio:
{ lib, ... }: lib.mkIf (audio.enable or false) {
  services.pipewire = {
    enable = true;
    pulse.enable = audio.pulse or true;
    alsa.enable = audio.alsa or true;
    alsa.support32Bit = audio.alsa32 or true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.libinput.enable = true;
}
