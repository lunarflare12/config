{
  lib,
  mkHyprlandPlugin,
  fetchFromGitHub,
}:

# Pinned to Hyprland 0.56.2 via upstream hyprpm.toml commit_pins.
mkHyprlandPlugin {
  pluginName = "HyprWindowShade";
  version = "0-unstable-2026-09-28";

  src = fetchFromGitHub {
    owner = "ManofJELLO";
    repo = "HyprWindowShade";
    rev = "a4c6b8af424a189072427c4c90ef2938e1b481d3";
    hash = "sha256-hFs3AVnH6j9ZnDzfG19pAL9cO+pVl21pT9q9A1c6DNw=";
  };

  dontUseCmakeConfigure = true;

  buildPhase = ''
    runHook preBuild
    make all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -f HyprWindowShade.so $out/lib/libHyprWindowShade.so
    ln -s libHyprWindowShade.so $out/lib/HyprWindowShade.so
    runHook postInstall
  '';

  meta = {
    description = "Per-window fragment shaders with open/close animations for Hyprland";
    homepage = "https://github.com/ManofJELLO/HyprWindowShade";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
