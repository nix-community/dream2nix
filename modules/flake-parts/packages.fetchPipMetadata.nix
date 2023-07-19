# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{
  self,
  inputs,
  ...
}: {
  perSystem = {
    system,
    config,
    lib,
    pkgs,
    ...
  }: {
    packages.fetchPipMetadata = pkgs.callPackage ../../pkgs/fetchPipMetadata/package.nix {
      python = pkgs.python3;
    };
  };
}
