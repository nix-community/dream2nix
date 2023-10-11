{
  self,
  lib,
  ...
}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    ...
  }: {
    render.inputs =
      lib.flip lib.mapAttrs
      (lib.filterAttrs (name: module:
        lib.elem name [
          # "buildPythonPackage"
          # "buildRustPackage"
          # "builtins-derivation"
          "core"
          # "groups"
          # "mkDerivation"
          # "mkDerivation-sane-defaults"
          # "nixpkgs-overrides"
          # "nodejs-devshell"
          # "nodejs-granular"
          # "nodejs-granular-v3"
          # "nodejs-node-modules"
          "nodejs-package-json"
          "nodejs-package-lock"
          "nodejs-package-lock-v3"
          "package-func"
          "php-composer-lock"
          "php-granular"

          "pip"
          "rust-cargo-lock"
          "WIP-python-pdm"
          "WIP-python-pyproject"
          "WIP-spago"

          "lock"
          "mkDerivation"
          "public"

          # NOT WORKING
          # "rust-crane"
          # "_template"
        ]) (self.modules.dream2nix))
      (name: module: {
        title = name;
        module = self.modules.dream2nix.${name};
        sourcePath = self;
        attributePath = [
          "dream2nix"
          "modules"
          "dream2nix"
          (lib.strings.escapeNixIdentifier name)
        ];
        intro = "intro";
        baseUrl = "https://github.com/nix-community/dream2nix/blob/master";
        separateEval = true;
      });
  };
}
