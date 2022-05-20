# A very simple single derivation python builder
{
  lib,
  pkgs,
  ...
}: {
  defaultPackageName,
  defaultPackageVersion,
  getSource,
  packageVersions,
  subsystemAttrs,
  ...
}: let
  l = lib // builtins;
  python = pkgs."${subsystemAttrs.pythonAttr}";

  buildFunc =
    if subsystemAttrs.application
    then python.pkgs.buildPythonApplication
    else python.pkgs.buildPythonPackage;

  packageName =
    if defaultPackageName == null
    then
      if subsystemAttrs.application
      then "application"
      else "environment"
    else defaultPackageName;

  allDependencySources' =
    l.flatten
    (l.mapAttrsToList
      (name: versions:
        if name == defaultPackageName
        then []
        else l.map (ver: getSource name ver) versions)
      packageVersions);

  allDependencySources =
    l.map
    (src: src.original or src)
    allDependencySources';

  package = buildFunc {
    name = packageName;
    src = getSource defaultPackageName defaultPackageVersion;
    format = "setuptools";
    buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    doCheck = false;
    preBuild = ''
      mkdir dist
      for file in ${builtins.toString allDependencySources}; do
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
      ${python}/bin/python -m pip install \
        ./dist/*.{whl,tar.gz,zip} \
        --no-index \
        --no-warn-script-location \
        --prefix="$out" \
        --no-cache \
        $pipInstallFlags
      runHook postInstall
    '';
  };
in {
  packages.${defaultPackageName}.${defaultPackageVersion} = package;
}
