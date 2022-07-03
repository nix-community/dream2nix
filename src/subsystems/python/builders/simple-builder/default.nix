# A very simple single derivation python builder
{...}: {
  type = "pure";

  build = {
    lib,
    pkgs,
    ...
  }: {
    defaultPackageName,
    defaultPackageVersion,
    getSource,
    packageVersions,
    subsystemAttrs,
    produceDerivation,
    ...
  }: let
    l = lib // builtins;
    python = pkgs."${subsystemAttrs.pythonAttr}";

    buildFunc =
      if subsystemAttrs.application
      then python.pkgs.buildPythonApplication
      else python.pkgs.buildPythonPackage;

    allDependencySources' =
      l.flatten
      (l.mapAttrsToList
        (name: versions:
          if l.elem name [defaultPackageName "setuptools" "pip"]
          then []
          else l.map (ver: getSource name ver) versions)
        packageVersions);

    allDependencySources =
      l.map
      (src: src.original or src)
      allDependencySources';

    package = produceDerivation defaultPackageName (buildFunc {
      name = defaultPackageName;
      src = getSource defaultPackageName defaultPackageVersion;
      format = "setuptools";
      buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      propagatedBuildInputs = [python.pkgs.setuptools];
      doCheck = false;
      dontStrip = true;
      preBuild = ''
        mkdir dist
        for file in ${builtins.toString allDependencySources}; do
          # pick right most element of path
          fname=''${file##*/}
          fname=$(stripHash $fname)
          cp $file dist/$fname
        done
        mkdir -p "$out/${python.sitePackages}"
        export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"
        ${python}/bin/python -m pip install \
          ./dist/*.{whl,tar.gz,zip} \
          --no-build-isolation \
          --no-index \
          --no-warn-script-location \
          --prefix="$out" \
          --no-cache \
          $pipInstallFlags
      '';
    });

    devShell = pkgs.mkShell {
      buildInputs = [
        # a drv with all dependencies without the main package
        (package.overrideAttrs (old: {
          src = ".";
          dontUnpack = true;
          buildPhase = old.preBuild;
        }))
      ];
    };
  in {
    packages.${defaultPackageName}.${defaultPackageVersion} = package;
    devShells.${defaultPackageName} = devShell;
    inherit devShell;
  };
}
