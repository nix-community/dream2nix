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
    ../../drv-parts/lock
  ];

  lock.fields.mach-nix.pythonSources = let
    safeFOD = config.mach-nix.pythonSources.overrideAttrs (old: {
      outputHash = "";
    });

    deps = safeFOD.overrideAttrs (old: {
      outputHash = null;
      phases = ["foo"];
      foo = "touch $out";
    });
  in
    config.deps.writeScript "update-FOD-hash-${config.public.name}" ''
      ${config.deps.nix}/bin/nix build -L ${l.unsafeDiscardStringContext deps.drvPath}
      hash=$(${config.deps.nix}/bin/nix build -L ${l.unsafeDiscardStringContext safeFOD.drvPath} 2>&1 \
        | tee /dev/tty | awk '/got/ {print $2}')
      echo "\"$hash\"" > $out
    '';

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
  };

  name = "ansible";
  version = "2.7.1";

  mkDerivation = {
    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "setuptools";

    pythonImportsCheck = [
      config.name
    ];
  };

  mach-nix.pythonSources = config.deps.fetchPip {
    inherit python;
    name = config.public.name;
    requirementsList = ["${config.public.name}==${config.public.version}"];
    hash = config.lock.content.mach-nix.pythonSources;
    maxDate = "2023-01-01";
  };
}
