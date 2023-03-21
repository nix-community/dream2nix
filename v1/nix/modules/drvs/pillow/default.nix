# Build Pillow from source, without a wheel, and rather
# minimal features - only zlib and libjpeg as dependencies.
{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
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

  mach-nix.pythonSources = config.deps.fetchPip {
    inherit python;
    name = config.name;
    requirementsList = ["${config.name}==${config.version}"];
    hash = "sha256-eS81pqSjU6mgBL6tXadSxkGdafsVFThByOQcOf8FkF0=";
    maxDate = "2023-01-01";
    pipFlags = [
      "--no-binary"
      ":all:"
    ];
  };
}
