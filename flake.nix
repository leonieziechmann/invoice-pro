{
  description = "invoice-pro dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = { self, nixpkgs, pre-commit-hooks }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      toml = builtins.fromTOML (builtins.readFile ./typst.toml);
      name = toml.package.name;
      version = toml.package.version;

    in
    {
      checks.${system}.pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          typstyle = {
            enable = true;
            name = "typstyle";
            entry = "${pkgs.typstyle}/bin/typstyle -i";
            files = "\\.typ$";
          };
          markdownlint.enable = true;
          prettier = {
            enable = true;
            types_or = [ "markdown" ];
          };
          nixpkgs-fmt.enable = true;
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          typst
          typstyle
          markdownlint-cli
          nodePackages.prettier
        ] ++ self.checks.${system}.pre-commit-check.enabledPackages;

        shellHook = ''
          ${self.checks.${system}.pre-commit-check.shellHook}

          export XDG_DATA_HOME="$PWD/.typst-data"
          export XDG_CACHE_HOME="$PWD/.typst-cache"

          PKG_DIR="$XDG_DATA_HOME/typst/packages/preview/${name}/${version}"

          echo "✨ Environment isolated. Data & Cache are local."

          mkdir -p "$(dirname "$PKG_DIR")"
          rm -rf "$PKG_DIR"
          ln -s "$PWD" "$PKG_DIR"

          echo "✔  Package linked! You can now use: #import \"@preview/${name}:${version}\": *"
        '';
      };
    };
}
