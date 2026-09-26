{
  systemArch = "x86_64-linux";
  stateVersion = "26.05";
  userName = "dd";
  repo = "Documents/projects/config";

  users = {
    dd = {
      description = "DD";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "wireshark"
      ];
    };
  };

  terminal = "kitty";
  browser = "google-chrome";
  fileManager = "thunar";
  cursorSize = 24;

  features = {
    docker = true;
    steam = true;
    libvirt = true;
    virt-manager = true;
    bluetooth = false;
    battery = false;
    whisper = true;
  };

  packages = [
    "terraform"
    "ansible"
    "go"
    "nodejs_latest"
    "claude-code"
    "python3"
    "ffmpeg"
    "code-cursor"
    "keymapp"
    "kubectl"
    "k9s"
    "kubernetes-helm"
    "kustomize"
    "kubectx"
    "stern"
    "fluxcd"
    "argocd"
    "dnsutils"
    "awscli2"
    "cloudflare-cli"
    "cloudflared"
    "flarectl"
    "jq"
    "yq-go"
    "burpsuite"
    "zap"
    "mitmproxy"
    "nmap"
    "rustscan"
    "masscan"
    "wireshark"
    "tcpdump"
    "termshark"
    "nuclei"
    "nikto"
    "whatweb"
    "ffuf"
    "gobuster"
    "feroxbuster"
    "amass"
    "subfinder"
    "testssl"
    "sslscan"
    "trivy"
    "grype"
    "syft"
    "gitleaks"
    "trufflehog"
    "semgrep"
    "osv-scanner"
    "checkov"
    "kubescape"
    "kube-score"
    "kubeconform"
    "dive"
    "whois"
    "mtr"
    "socat"
    "httpie"
    "btop"
    "vagrant"
    "vlc"
    "xournalpp"
  ];

  monitors = [
    {
      output = "DP-1";
      mode = "2560x1080@200.00Hz";
      position = "0x0";
      scale = 1;
      bitdepth = 8;
    }
    {
      output = "HDMI-A-1";
      mode = "1920x1080@60.00Hz";
      position = "2560x0";
      scale = 1;
      bitdepth = 8;
    }
  ];

  input = {
    kbLayout = "us,ru";
    sensitivity = 0;
    naturalScroll = false;
  };

  git = {
    userName = "lunarflare";
    userEmail = "tes@gmail.com";
  };
}
