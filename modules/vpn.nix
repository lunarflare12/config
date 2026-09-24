{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  vpnCtl = pkgs.writeShellApplication {
    name = "vpn-ctl";
    runtimeInputs = [
      pkgs.python3
      pkgs.iproute2
      pkgs.wireguard-tools
      pkgs.amneziawg-tools
      pkgs.amneziawg-go
      pkgs.sing-box
    ];
    text = ''
      exec python3 /home/${host.userName}/.config/scripts/lab-ctl.py "$@"
    '';
  };
in
{
  networking = {
    wireguard.enable = true;
    firewall.checkReversePath = "loose";
    networkmanager.plugins = [ pkgs.networkmanager-openconnect ];
  };

  boot = {
    extraModulePackages = lib.optional (
      config.boot.kernelPackages ? amneziawg
    ) config.boot.kernelPackages.amneziawg;
    kernelModules = [
      "wireguard"
    ]
    ++ lib.optional (config.boot.kernelPackages ? amneziawg) "amneziawg";
  };

  environment.systemPackages = [
    pkgs.wireguard-tools
    pkgs.amneziawg-tools
    pkgs.amneziawg-go
    pkgs.openconnect
    pkgs.networkmanager-openconnect
    pkgs.sing-box
    vpnCtl
  ];

  systemd.tmpfiles.rules = [
    "d /etc/wireguard 0750 root wheel -"
    "d /etc/amnesia 0750 root wheel -"
    "d /etc/amnesia/vless 0750 root wheel -"
  ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.aurora.vpnctl" && subject.local && subject.active && subject.user == "${host.userName}") {
        return polkit.Result.YES;
      }
    });
  '';

  environment.etc."polkit-1/actions/org.aurora.vpnctl.policy".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <action id="org.aurora.vpnctl">
        <description>Toggle Aurora VPN tunnels</description>
        <message>Authentication is required to change a WireGuard or Amnezia tunnel</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>yes</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${lib.getExe vpnCtl}</annotate>
        <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
      </action>
    </policyconfig>
  '';

  security.sudo.extraRules = [
    {
      users = [ host.userName ];
      commands = [
        {
          command = lib.getExe vpnCtl;
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/vpn-ctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
