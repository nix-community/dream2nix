{
  lib,
  pkgs,
}:

{
  fetchedSources,
  genericLock,
}:

let
  python = pkgs."${genericLock.buildSystem.pythonAttr}";
in

python.pkgs.buildPythonPackage {
  name = "python-environment";
  format = "";
  src = lib.attrValues fetchedSources;
  buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
  nativeBuildInputs = [ pkgs.autoPatchelfHook python.pkgs.wheelUnpackHook ];
  unpackPhase = ''
    mkdir dist 
    for file in $src; do
      fname=$(echo $file | cut -d "-" -f 2-)
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
