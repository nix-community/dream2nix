{
  self,
  lib,
  ...
}: {
  imports = [
    ./render
    ./site
  ];
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    ...
  }: let
    excludes = [
      # NOT WORKING
      # TODO: fix those
      "core"
      "ui"
      "docs"
      "assertions"
      "nixpkgs-overrides"

      # doesn't need to be rendered
      "_template"
    ];
    public = lib.genAttrs [
      "nodejs-devshell-v3"
      "nodejs-node-modules-v3"
      "nodejs-package-json-v3"
      "nodejs-package-lock-v3"
      "php-composer-lock"
      "pip"
      "rust-cargo-lock"
      "rust-crane"
    ] (name: null);
  in {
    render.inputs =
      lib.flip lib.mapAttrs
      (lib.filterAttrs
        (name: module:
          ! (lib.elem name excludes))
        (self.modules.dream2nix))
      (name: module: {
        inherit module;
        title = name;
        sourcePath = self;
        attributePath = [
          "dream2nix"
          "modules"
          "dream2nix"
          (lib.strings.escapeNixIdentifier name)
        ];
        intro =
          if lib.pathExists ../dream2nix/${name}/README.md
          then lib.readFile ../dream2nix/${name}/README.md
          else "";
        baseUrl = "https://github.com/nix-community/dream2nix/blob/master";
        separateEval = true;
        chapter =
          if public ? ${name}
          then "Modules"
          else "Modules (Internal + Experimental)";
      });
  };
}
