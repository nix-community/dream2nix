# A very simple single derivation python builder

{
  lib,
  pkgs,
  ...
}:

{
  fetchedSources,
  dreamLock,
}:

let
  python = pkgs."${dreamLock.buildSystem.pythonAttr}";

  buildFunc =
    if dreamLock.buildSystem.application then
      python.pkgs.buildPythonApplication
    else
      python.pkgs.buildPythonPackage;

  mainPackageName = dreamLock.generic.mainPackage;

  packageName =
    if mainPackageName == null then
      if dreamLock.buildSystem.application then
        "application"
      else
        "environment"
    else
      mainPackageName;
in

buildFunc {
  name = packageName;
  format = "";
  src = fetchedSources."${toString (mainPackageName)}" or null;
  buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
  nativeBuildInputs = [ pkgs.autoPatchelfHook python.pkgs.wheelUnpackHook ];
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
}
