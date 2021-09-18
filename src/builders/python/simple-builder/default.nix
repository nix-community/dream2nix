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
in

python.pkgs.buildPythonPackage {
  name = "python-environment";
  format = "";
  src = lib.attrValues fetchedSources;
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
    ${python}/bin/python -m pip install ./dist/*.{whl,tar.gz,zip} \
      --no-index \
      --no-warn-script-location \
      --prefix="$out" \
      --no-cache $pipInstallFlags \
      --ignore-installed
    runHook postInstall
  '';
}
