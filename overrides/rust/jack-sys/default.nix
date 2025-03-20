{
  config,
  lib,
  ...
}: {
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) pkg-config libjack2;
  };

  mkDerivation.buildInputs = [ config.deps.libjack2 ];
  mkDerivation.nativeBuildInputs = [ config.deps.pkg-config ];
}
