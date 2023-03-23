# Build Pillow from source, without a wheel, and rather
# minimal features - only zlib and libjpeg as dependencies.
{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
    inherit
      (nixpkgs)
      pkg-config
      zlib
      libjpeg
      ;
  };

  name = "pillow";
  version = "9.3.0";

  mkDerivation = {
    nativeBuildInputs = [
      config.deps.pkg-config
    ];
    propagatedBuildInputs = [
      config.deps.zlib
      config.deps.libjpeg
    ];

    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "setuptools";

    pythonImportsCheck = [
      "PIL"
    ];
  };

  mach-nix.pythonSources.fetch-pip = {
    maxDate = "2023-01-01";
    requirementsList = ["${config.name}==${config.version}"];
    pipFlags = [
      "--no-binary"
      ":all:"
    ];
  };
}
