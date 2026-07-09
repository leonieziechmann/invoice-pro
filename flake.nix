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
          set -e

          if [ ! -f "typst.toml" ]; then
            echo "Error: validate-zugferd must be run from the root of the invoice-pro repository." >&2
            exit 1
          fi

          if [ -z "$1" ]; then
            echo "Usage: validate-zugferd <typst-document> [output-path]" >&2
            exit 1
          fi

          src_file="$1"
          output_path="$2"

          tmp_dir=$(mktemp -d)
          # Cleanup temp dir on exit unless it is empty/deleted
          trap 'rm -rf "$tmp_dir"' EXIT

          if [ -n "$output_path" ]; then
            pdf_path="$output_path"
          else
            name=$(basename "$src_file" .typ)
            pdf_path="$tmp_dir/$name.pdf"
          fi

          extract_dir="$tmp_dir/extracted"
          mkdir -p "$extract_dir"

          echo "Compiling ZUGFeRD PDF for $src_file..."
          ${typstEnv}/bin/typst compile \
            --root . \
            --pdf-standard=a-3b \
            "$src_file" \
            "$pdf_path"

          echo "Extracting factur-x.xml..."
          ${pkgs.poppler-utils}/bin/pdfdetach -saveall -o "$extract_dir" "$pdf_path"

          if [ ! -f "$extract_dir/factur-x.xml" ]; then
            echo "Error: factur-x.xml not found in compiled PDF!" >&2
            exit 1
          fi

          echo "Validating ZUGFeRD XML..."
          ${mustang-cli}/bin/mustang-cli --action validate --source "$extract_dir/factur-x.xml"
        '';

        validate-all-zugferd = pkgs.writeScriptBin "validate-all-zugferd" ''
          #!/usr/bin/env bash
          set -e

          if [ ! -f "typst.toml" ]; then
            echo "Error: validate-all-zugferd must be run from the root of the invoice-pro repository." >&2
            exit 1
          fi

          echo "========================"
          echo " Running all ZUGFeRD validations... "
          echo "========================"

          ${validate-zugferd}/bin/validate-zugferd "tests/integration/zugferd-basic/test.typ"
          ${validate-zugferd}/bin/validate-zugferd "tests/integration/zugferd-small-biz/test.typ"
          ${validate-zugferd}/bin/validate-zugferd "template/invoice.typ"

          echo ""
          echo "✔ All ZUGFeRD validations passed!"
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
          npmDepsHash = "sha256-XjBCbNybXdX87+3uYERtGPFjj+zrsop5DYRVgIgvIfI=";
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
          EXCLUDE="-g '!docs/versioned_docs/' -g '!docs/versioned_sidebars/' -g '!docs/build/' -g '!docs/node_modules/' -g '!docs/.docusaurus/'"
          GLOBS="-g '*.typ' -g '*.md' -g '*.toml'"

          echo "Current version: ${version}"
          echo ""
          echo "Searching for stale version references..."
          echo "==========================================="

          if [ -z "$1" ]; then
            echo "Usage: check-version <old-version>"
            echo "  e.g. check-version 0.3.0"
            exit 1
          fi

          OLD="$1"
          echo ""
          echo "--- Stale references to $OLD (should be empty) ---"
          eval "${pkgs.ripgrep}/bin/rg \"$OLD\" $GLOBS $EXCLUDE" || echo "  ✔ No stale references found."
          echo ""
          echo "--- Current references to ${version} ---"
          eval "${pkgs.ripgrep}/bin/rg \"${version}\" $GLOBS $EXCLUDE"
        '';

        packages.check-pr = pkgs.writeScriptBin "check-pr" ''
          #!/usr/bin/env bash
          set -e

          echo "========================"
          echo " Running PR checks... "
          echo "========================"

          echo ""
          echo "[1/4] Running linter..."
          nix build .#checks.''${system}.lint --print-build-logs

          echo ""
          echo "[2/4] Running tests..."
          nix develop .#test --accept-flake-config --command tt run

          echo ""
          echo "[3/4] Building documentation..."
          nix build .#documentation --print-build-logs

           echo ""
           echo "[4/4] Validating ZUGFeRD PDF..."
           nix run .#validate-all-zugferd --accept-flake-config

          echo ""
          echo "✔ All checks passed successfully!"
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
