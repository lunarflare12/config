{
  config,
  lib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  containersSrc = ./dots/containers;
  dest = ".local/share/aurora/containers";

  # Static stack files shipped in the repo (secrets/.env stay generated or local).
  appsFiles = [
    "compose.yml"
    "Dockerfile"
    "entrypoint.sh"
    "chrome-policy.json"
  ];
  steamFiles = [
    "compose.yml"
    "Dockerfile"
    "entrypoint.sh"
    "game-session.sh"
    "albion-entry.sh"
    "terraria-entry.sh"
    "steam-profile"
  ];
  telegramFiles = [
    "compose.yml"
    "Dockerfile"
    "entrypoint.sh"
    "td-setup.tar.xz"
  ];
  llmFiles = [
    "compose.yml"
    "searxng/settings.yml"
    "searxng/settings.yml.example"
    ".env.example"
  ];

  link =
    stack: name:
    let
      executable = lib.hasSuffix ".sh" name || name == "entrypoint.sh";
    in
    {
      name = "${dest}/${stack}/${name}";
      value = {
        source = "${containersSrc}/${stack}/${name}";
        force = true;
      }
      // lib.optionalAttrs executable { executable = true; };
    };
in
{
  # Deploy live container definitions from the git tree so a fresh machine
  # gets the same compose/Dockerfiles as this host.
  home.file = lib.listToAttrs (
    map (link "apps") appsFiles
    ++ map (link "steam") steamFiles
    ++ map (link "telegram") telegramFiles
    ++ map (link "llm") llmFiles
  );

  # Keep an llm .env if present; otherwise seed from the example once.
  home.activation.seedLlmEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    llm_dir="${homeDir}/${dest}/llm"
    mkdir -p "$llm_dir"
    if [ ! -f "$llm_dir/.env" ] && [ -f "$llm_dir/.env.example" ]; then
      cp -f "$llm_dir/.env.example" "$llm_dir/.env"
      chmod 600 "$llm_dir/.env"
    fi
  '';
}
