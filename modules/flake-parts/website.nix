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
    render.inputs = {
      core = {
        title = "core";
        flake.module = self.modules.dream2nix.core;
        flake.outPath = self;
        attributePath = ["module"];
        intro = "intro";
        baseUrl = "https://github.com/nix-community/dream2nix/blob/master";
      };
    };
  };
}
