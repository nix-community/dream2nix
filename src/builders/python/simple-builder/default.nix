# A very simple single derivation python builder
{
  lib,
  pkgs,
  ...
}: {
  fetchedSources,
  dreamLock,
}: let
  python = pkgs."${dreamLock._subsystem.pythonAttr}";

  buildFunc =
    if dreamLock._subsystem.application
    then python.pkgs.buildPythonApplication
    else python.pkgs.buildPythonPackage;

  defaultPackage = dreamLock._generic.defaultPackage;

  packageName =
    if defaultPackage == null
    then
      if dreamLock._subsystem.application
      then "application"
      else "environment"
    else defaultPackage;

  defaultPackage = buildFunc {
    name = packageName;
    format = "";
    buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
    nativeBuildInputs = [pkgs.autoPatchelfHook python.pkgs.wheelUnpackHook];
    unpackPhase = ''
      mkdir dist
      for file in ${builtins.toString (lib.attrValues fetchedSources)}; do
        # pick right most element of path
        fname=''${file##*/}
        fname=$(stripHash $fname)
        cp $file dist/$fname
      done
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/${python.sitePackages}"
      export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"
      ${python}/bin/python -m pip install ./dist/*.{whl,tar.gz,zip} $src \
        --no-index \
        --no-warn-script-location \
        --prefix="$out" \
        --no-cache $pipInstallFlags \
        --ignore-installed
      runHook postInstall
    '';
  };
in {
  inherit defaultPackage;
}
