{ pkgs, ... }:

{
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vkcapture
      obs-pipewire-audio-capture
      obs-vertical-canvas
      obs-aitum-multistream
      obs-multi-rtmp
    ];
  };

  environment.systemPackages = [
    pkgs.v4l-utils
  ];
}
