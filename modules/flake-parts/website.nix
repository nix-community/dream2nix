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
  }: let
    excludes = [
      # NOT WORKING
      # TODO: fix those
      "nixpkgs-overrides"
      "core"
      "flags"
      "ui"
      "docs"
      "env"
      "assertions"

      # doesn't need to be rendered
      "_template"
    ];
  in {
    render.inputs =
      lib.flip lib.mapAttrs
      (lib.filterAttrs
        (name: module:
          ! (lib.elem name excludes))
        (self.modules.dream2nix))
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
