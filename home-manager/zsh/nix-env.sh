# Sourced from zsh on every platform — restores `nix` after reboot (absolute paths).
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
  # shellcheck disable=SC1091
  . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
fi
