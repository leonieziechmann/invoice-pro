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

        # KoSIT, the reference validator for XRechnung, and its XRechnung
        # configuration (KOSIT_JAR and KOSIT_CONFIG of tools/zugferd).
        kosit-validator = pkgs.stdenv.mkDerivation rec {
          pname = "kosit-validator";
          version = "1.6.3";

          src = pkgs.fetchurl {
            url = "https://github.com/itplr-kosit/validator/releases/download/v${version}/validator-${version}-standalone.jar";
            hash = "sha256-eZ5kvvypfUCA4DYIyAuF3VpezF9K5PNdERbsKFW5p8k=";
          };

          dontUnpack = true;

          installPhase = ''
            mkdir -p $out/share/java
            cp $src $out/share/java/kosit-validator.jar
          '';
        };

        xrechnung-configuration = pkgs.stdenv.mkDerivation rec {
          pname = "xrechnung-configuration";
          version = "2026-08-31";

          src = pkgs.fetchurl {
            url = "https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/download/v${version}/xrechnung-3.0.2-validator-configuration-${version}.zip";
            hash = "sha256-JTDNEHxBRRHF0EYuwQ+IaRA5Wr/Kgg24LoPXC/ASIag=";
          };

          dontUnpack = true;

          nativeBuildInputs = [ pkgs.unzip ];

          installPhase = ''
            mkdir -p $out/share/kosit/xrechnung
            unzip -q $src -d $out/share/kosit/xrechnung
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
          export PYTHON="${toolsPython}/bin/python3"
          export JAVA_BIN="${pkgs.jre_headless}/bin/java"
          export KOSIT_JAR="${kosit-validator}/share/java/kosit-validator.jar"
          export KOSIT_CONFIG="${xrechnung-configuration}/share/kosit/xrechnung"
          exec ${pkgs.bash}/bin/bash ${./scripts/validate-all-zugferd} "$@"
        '';

        check-docs-examples = pkgs.writeScriptBin "check-docs-examples" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:$PATH"
          exec ${pkgs.bash}/bin/bash ${./scripts/check-docs-examples} "$@"
        '';

        # Python of the conformance and performance tools (tools/zugferd, tools/perf).
        toolsPython = pkgs.python3.withPackages (ps: [
          ps.lxml
          ps.pypdf
        ]);

        zugferd-corpus = pkgs.writeScriptBin "zugferd-corpus" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PYTHON="${toolsPython}/bin/python3"
          export JAVA_BIN="${pkgs.jdk_headless}/bin/java"
          export JAVAC_BIN="${pkgs.jdk_headless}/bin/javac"
          export MUSTANG_JAR="${mustang-cli}/share/java/mustang-cli.jar"
          export KOSIT_JAR="${kosit-validator}/share/java/kosit-validator.jar"
          export KOSIT_CONFIG="${xrechnung-configuration}/share/kosit/xrechnung"
          exec ${pkgs.bash}/bin/bash ${./scripts/zugferd-corpus} "$@"
        '';

        zugferd-xmp = pkgs.writeScriptBin "zugferd-xmp" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PYTHON="${toolsPython}/bin/python3"
          export JAVA_BIN="${pkgs.jdk_headless}/bin/java"
          export JAVAC_BIN="${pkgs.jdk_headless}/bin/javac"
          export MUSTANG_JAR="${mustang-cli}/share/java/mustang-cli.jar"
          exec ${pkgs.bash}/bin/bash ${./scripts/zugferd-xmp} "$@"
        '';

        # The plain Typst: the check provides the packages itself, so it must
        # not see the package path of typstEnv.
        check-package-bundle = pkgs.writeScriptBin "check-package-bundle" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${pkgs.typst}/bin/typst"
          export PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:$PATH"
          exec ${pkgs.bash}/bin/bash ${./scripts/check-package-bundle} "$@"
        '';

        zugferd-golden = pkgs.writeScriptBin "zugferd-golden" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PYTHON="${toolsPython}/bin/python3"
          exec ${pkgs.bash}/bin/bash ${./scripts/zugferd-golden} "$@"
        '';

        perf-gate = pkgs.writeScriptBin "perf-gate" ''
          #!/usr/bin/env bash
          export TYPST_BIN="${typstEnv}/bin/typst"
          export PYTHON="${toolsPython}/bin/python3"
          exec ${pkgs.bash}/bin/bash ${./scripts/perf-gate} "$@"
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

        apps.check-docs-examples = {
          type = "app";
          program = "${check-docs-examples}/bin/check-docs-examples";
        };

        apps.zugferd-corpus = {
          type = "app";
          program = "${zugferd-corpus}/bin/zugferd-corpus";
        };

        apps.zugferd-golden = {
          type = "app";
          program = "${zugferd-golden}/bin/zugferd-golden";
        };

        apps.perf-gate = {
          type = "app";
          program = "${perf-gate}/bin/perf-gate";
        };

        apps.zugferd-xmp = {
          type = "app";
          program = "${zugferd-xmp}/bin/zugferd-xmp";
        };

        apps.check-package-bundle = {
          type = "app";
          program = "${check-package-bundle}/bin/check-package-bundle";
        };

        packages.default = invoice-proPackage;

        packages.validate-zugferd = validate-zugferd;
        packages.validate-all-zugferd = validate-all-zugferd;
        packages.check-docs-examples = check-docs-examples;
        packages.zugferd-corpus = zugferd-corpus;
        packages.zugferd-golden = zugferd-golden;
        packages.perf-gate = perf-gate;
        packages.zugferd-xmp = zugferd-xmp;
        packages.check-package-bundle = check-package-bundle;
        packages.poppler-utils = pkgs.poppler-utils;
        # The pinned validators; .github/workflows/upstream-check.yaml reads
        # their versions.
        packages.mustang-cli = mustang-cli;
        packages.kosit-validator = kosit-validator;
        packages.xrechnung-configuration = xrechnung-configuration;

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
          export KOSIT_JAR="${kosit-validator}/share/java/kosit-validator.jar"
          export KOSIT_CONFIG="${xrechnung-configuration}/share/kosit/xrechnung"
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
            self.packages.${system}.check-docs-examples
            self.packages.${system}.zugferd-corpus
            self.packages.${system}.zugferd-golden
            self.packages.${system}.perf-gate
            self.packages.${system}.zugferd-xmp
            self.packages.${system}.check-package-bundle
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
