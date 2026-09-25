{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      params = import ./configurations-params/home-pc.nix;
      inherit (params) systemArch;
      host = import ./lib/host.nix { inherit lib params; };
      desktopEnv = import ./lib/desktop-env.nix;
      overlay = import ./pkgs;
      pkgs = import nixpkgs {
        system = systemArch;
        overlays = [ overlay ];
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "python3.14-ecdsa-0.19.2"
        ];
      };
      space = import ./lib/space.nix {
        inherit lib pkgs desktopEnv;
      };
    in
    {
      overlays.default = overlay;

      nixosConfigurations.nixos = lib.nixosSystem {
        specialArgs = {
          inherit
            params
            inputs
            host
            desktopEnv
            space
            ;
        };
        modules = [
          { nixpkgs.pkgs = pkgs; }
          ./configuration.nix
          ./hardware-configuration.nix
          ./modules
          home-manager.nixosModules.home-manager
        ];
      };

      formatter.${systemArch} = pkgs.nixfmt-tree;

      devShells.${systemArch}.default = pkgs.mkShellNoCC {
        # qtdeclarative carries qmlformat and qmllint.
        packages = [
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
          pkgs.qt6.qtdeclarative
        ];
      };

      checks.${systemArch} =
        let
          nixSources = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (lib.fileset.maybeMissing ./statix.toml)
              (lib.fileset.fileFilter (file: file.hasExt "nix") ./.)
            ];
          };

          # maybeMissing: a flake only sees git-tracked files, and the two tool
          # configs break evaluation here until they are added to the index.
          qmlSources = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (lib.fileset.maybeMissing ./.qmlformat.ini)
              (lib.fileset.maybeMissing ./.qmllint.ini)
              (lib.fileset.fileFilter (file: file.hasExt "qml") ./.)
            ];
          };

          # qmllint resolves Quickshell's own types plus the shell's
          # core/components/modules/services directories.
          qmlImports = lib.concatMapStringsSep " " (path: "-I ${path}") [
            "${pkgs.quickshell}/lib/qt-6/qml"
            "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
            "home/dots/aurora-qs"
          ];

          check =
            name: tools: script:
            pkgs.runCommand "check-${name}" { nativeBuildInputs = tools; } ''
              ${script}
              touch "$out"
            '';
        in
        {
          # Records the toplevel derivation path as plain text. The string
          # context is discarded on purpose: this check proves the system
          # evaluates without pulling the whole closure through a build.
          eval = pkgs.runCommand "nixos-eval" {
            drvPath = builtins.unsafeDiscardStringContext self.nixosConfigurations.nixos.config.system.build.toplevel.drvPath;
          } "echo \"$drvPath\" > \"$out\"";

          nix-format = check "nix-format" [ pkgs.nixfmt ] ''
            find ${nixSources} -name '*.nix' -print0 | xargs -0 nixfmt --check
          '';

          nix-statix = check "nix-statix" [ pkgs.statix ] ''
            statix check --config "${nixSources}" "${nixSources}"
          '';

          nix-deadnix = check "nix-deadnix" [ pkgs.deadnix ] ''
            deadnix --fail "${nixSources}"
          '';

          # qmlformat has no --check mode, so format a copy and diff it back.
          qml-format = check "qml-format" [ pkgs.qt6.qtdeclarative ] ''
            cp -r --no-preserve=mode,ownership "${qmlSources}" work
            cd work
            find . -name '*.qml' -print0 | xargs -0 qmlformat -i
            cd ..
            if ! diff -r "${qmlSources}" work; then
              echo "QML is not formatted. Run: qmlformat -i \$(git ls-files '*.qml')" >&2
              exit 1
            fi
          '';

          # Warning levels live in .qmllint.ini; info-level findings do not fail.
          qml-lint = check "qml-lint" [ pkgs.qt6.qtdeclarative ] ''
            cd "${qmlSources}"
            find . -name '*.qml' -print0 | xargs -0 qmllint ${qmlImports}
          '';
        };
    };
}
