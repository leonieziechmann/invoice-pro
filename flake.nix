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

      in
      {
        packages.default = invoice-proPackage;

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
          ] ++ self.checks.${system}.pre-commit-check.enabledPackages;

          shellHook = ''
            ${self.checks.${system}.pre-commit-check.shellHook}
            echo "✔  Packages linked! You can now use:"
            echo "    @preview/${name}:${version}"
            echo "    @preview/loom:${loomPackage.version}"
          '';
        };

        docs = pkgs.mkShell {
          builtins = with pkgs; [ nodejs typst ];
        };
      }
    );
}
