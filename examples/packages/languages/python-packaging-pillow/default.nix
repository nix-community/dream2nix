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
    python = nixpkgs.python39;
    inherit
      (nixpkgs)
      pkg-config
      zlib
      libjpeg
      ;
  };

  name = "pillow";
  version = "9.5.0";

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

  pip = {
    requirementsList = ["${config.name}==${config.version}"];
    pipFlags = [
      "--no-binary"
      ":all:"
    ];
  };
}
