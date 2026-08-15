{
  description = "invoice-pro dev environment";

  nixConfig = {
    extra-substituters = [ "https://typ-flow.cachix.org" ];
    extra-trusted-public-keys = [ "typ-flow.cachix.org-1:WEY45Irm+quH9n4ENB5rOxkdxfgkTcB3iMtdaADjf9s=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    flake-utils.url = "github:numtide/flake-utils";
    tytanic.url = "github:typst-community/tytanic/v0.3.3";
    typst-utils.url = "github:leonieziechmann/typst-nix-utils";
    loom.url = "github:leonieziechmann/loom";
  };

  outputs = { self, nixpkgs, pre-commit-hooks, flake-utils, typst-utils, tytanic, loom, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        toml = fromTOML (builtins.readFile ./typst.toml);
        name = toml.package.name;
        version = toml.package.version;

        invoice-proPackage = typst-utils.lib.buildTypstPackage {
          inherit pkgs;
          pname = toml.package.name;
          version = toml.package.version;
          src = ./.;
          files = [
            "typst.toml"
            "LICENSE"
            "src"
            "template"
          ];
        };

        loomPackage = loom.packages.${system}.default;

        typstEnv = typst-utils.lib.mkTypstEnv {
          inherit pkgs;
          typst = pkgs.typst;
          packages = [
            invoice-proPackage
            loomPackage
          ];
        };

        mustang-cli = pkgs.stdenv.mkDerivation rec {
          pname = "mustang-cli";
          version = "2.14.0";

          src = pkgs.fetchurl {
            url = "https://github.com/ZUGFeRD/mustangproject/releases/download/core-${version}/Mustang-CLI-${version}.jar";
            sha256 = "0yj3knyjp7rnmcvb8snm3f8famg2rankxfcfaqsnymkn4zc1lnb5";
          };

          dontUnpack = true;

          nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

          installPhase = ''
            mkdir -p $out/share/java
            cp $src $out/share/java/mustang-cli.jar

            makeWrapper ${pkgs.jre_headless}/bin/java $out/bin/mustang-cli \
              --add-flags "-jar $out/share/java/mustang-cli.jar"
          '';
        };

        validate-zugferd = pkgs.writeScriptBin "validate-zugferd" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PDFDETACH_BIN="${pkgs.poppler-utils}/bin/pdfdetach"
          export MUSTANG_CLI_BIN="${mustang-cli}/bin/mustang-cli"
          exec ${pkgs.bash}/bin/bash ${./scripts/validate-zugferd} "$@"
        '';

        validate-all-zugferd = pkgs.writeScriptBin "validate-all-zugferd" ''
          #!/usr/bin/env bash
          export VALIDATE_ZUGFERD_BIN="${validate-zugferd}/bin/validate-zugferd"
          exec ${pkgs.bash}/bin/bash ${./scripts/validate-all-zugferd} "$@"
        '';

      in
      {
        apps.default = {
          type = "app";
          program = "${pkgs.writeScriptBin "typst-wrapper" ''
            #!/usr/bin/env bash
            if [ $# -eq 0 ] || [[ "$1" == *.typ ]]; then
              exec ${typstEnv}/bin/typst compile "$@"
            else
              exec ${typstEnv}/bin/typst "$@"
            fi
          ''}/bin/typst-wrapper";
        };

        apps.validate-zugferd = {
          type = "app";
          program = "${validate-zugferd}/bin/validate-zugferd";
        };

        apps.validate-all-zugferd = {
          type = "app";
          program = "${validate-all-zugferd}/bin/validate-all-zugferd";
        };

        packages.default = invoice-proPackage;

        packages.validate-zugferd = validate-zugferd;
        packages.validate-all-zugferd = validate-all-zugferd;
        packages.poppler-utils = pkgs.poppler-utils;

        packages.documentation = pkgs.buildNpmPackage {
          pname = "invoice-pro-documentation";
          inherit version;
          src = ./docs;
          npmDepsHash = "sha256-G51i2btlv0pBO4XDAkVOB5MCTJhTBp5vutr5slpwD+I=";
          installPhase = ''
            mkdir -p $out
            cp -r build/* $out/
          '';
        };

        packages.release = pkgs.runCommand "invoice-pro-release" { } ''
          PACKAGE_DIR="invoice-pro-v${version}"
          mkdir -p $PACKAGE_DIR
          cp -r ${./typst.toml} $PACKAGE_DIR/typst.toml
          cp -r ${./thumbnail.png} $PACKAGE_DIR/thumbnail.png || true
          cp -r ${./LICENSE} $PACKAGE_DIR/LICENSE
          cp -r ${./src} $PACKAGE_DIR/src
          cp -r ${./template} $PACKAGE_DIR/template

          mkdir -p $out
          tar -czvf $out/invoice-pro-v${version}.tar.gz $PACKAGE_DIR
        '';

        packages.check-version = pkgs.writeScriptBin "check-version" ''
          #!/usr/bin/env bash
          export RIPGREP_BIN="${pkgs.ripgrep}/bin/rg"
          export VERSION="${version}"
          exec ${pkgs.bash}/bin/bash ${./scripts/check-version} "$@"
        '';

        packages.check-pr = pkgs.writeScriptBin "check-pr" ''
          #!/usr/bin/env bash
          exec ${pkgs.bash}/bin/bash ${./scripts/check-pr} "$@"
        '';

        checks.lint = self.checks.${system}.pre-commit-check;

        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            typstyle = { enable = true; name = "typstyle"; entry = "${pkgs.typstyle}/bin/typstyle -i"; files = "\\.typ$"; };
            prettier = { enable = true; types_or = [ "markdown" ]; };
            nixpkgs-fmt.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            typstEnv
            typstyle
            nodePackages.prettier
            nodejs
            yarn
            ripgrep
            tytanic.packages.${system}.default
            self.packages.${system}.check-version
            self.packages.${system}.check-pr
            self.packages.${system}.validate-zugferd
            self.packages.${system}.validate-all-zugferd
          ] ++ self.checks.${system}.pre-commit-check.enabledPackages;

          shellHook = ''
            ${self.checks.${system}.pre-commit-check.shellHook}
            echo "✔  Packages linked! You can now use:"
            echo "    @preview/${name}:${version}"
            echo "    @preview/loom:${loomPackage.version}"
          '';
        };

        devShells.test = pkgs.mkShell {
          buildInputs = [
            typstEnv
            tytanic.packages.${system}.default
          ];
        };
      }
    );
}
