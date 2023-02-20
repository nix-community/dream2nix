# Build Pillow from source, without a wheel, and rather
# minimal features - only zlib and libjpeg as dependencies.
{config, lib, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
    inherit (nixpkgs)
      pkg-config
      zlib
      libjpeg;
  };

  nativeBuildInputs = [
    config.deps.pkg-config
  ];
  propagatedBuildInputs = [
     config.deps.zlib config.deps.libjpeg
  ];

  pname = "pillow";
  version = "9.3.0";
  env.format = "setuptools";

  env.pythonImportsCheck = [
    "PIL"
  ];

  preUnpack = ''
    export src=$(ls ${config.mach-nix.pythonSources}/names/${config.pname}/*);
  '';

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit python;
    name = config.pname;
    requirementsList = ["${config.pname}==${config.version}"];
    hash = "sha256-/7MQ/hi+G3Q+xiDpEIw76chcwFmhKpipAq/4pkSvlm4=";
    maxDate = "2023-01-01";
    pipFlags = [
      "--no-binary" ":all:"
    ];
  };
}
