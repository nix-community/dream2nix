# Build Pillow from source, without a wheel, and rather
# minimal features - only zlib and libjpeg as dependencies.
{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python311;
    inherit
      (nixpkgs)
      pkg-config
      zlib
      libjpeg
      ;
  };

  name = "pillow";
  version = "10.4.0";

  mkDerivation = {
    nativeBuildInputs = [
      config.deps.pkg-config
    ];
    propagatedBuildInputs = [
      config.deps.zlib
      config.deps.libjpeg
    ];
  };

  buildPythonPackage = {
    pythonImportsCheck = [
      "PIL"
    ];
  };

  paths.lockFile = "lock.${config.deps.stdenv.system}.json";
  pip = {
    requirementsList = ["${config.name}==${config.version}"];
    pipFlags = [
      "--no-binary"
      ":all:"
    ];
  };
}
