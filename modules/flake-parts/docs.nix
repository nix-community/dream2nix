{
  self,
  lib,
  ...
}: {
  perSystem = {
    self',
    pkgs,
    ...
  }: {
    packages.docs = self'.packages.website;
  };
}
