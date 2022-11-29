# A very simple single derivation python builder
{
  pkgs,
  lib,
  ...
}: {
  type = "pure";

  build = {
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
          if l.elem name [defaultPackageName "setuptools" "pip" "wheel"]
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
      format = "other";
      buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
      nativeBuildInputs =
        [pkgs.autoPatchelfHook]
        ++ (with python.pkgs; [
          pip
          wheel
        ]);
      propagatedBuildInputs = [python.pkgs.setuptools];
      doCheck = false;
      dontStrip = true;

      buildPhase = ''
        mkdir dist
        for file in ${builtins.toString allDependencySources}; do
          # pick right most element of path
          fname=''${file##*/}
          fname=$(stripHash $fname)
          cp $file dist/$fname
        done

        mkdir -p "$out/${python.sitePackages}"
        export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"

        pipInstallFlags="--find-links ./dist/ \
          --no-build-isolation \
          --no-index \
          --no-warn-script-location \
          --prefix="$out" \
          --no-cache \
          --ignore-installed \
          $pipInstallFlags"
        ${python}/bin/python -m pip install $pipInstallFlags ${lib.concatStringsSep " " subsystemAttrs.buildRequirements}
        ${python}/bin/python -m pip wheel --verbose --no-index --no-deps --no-clean --no-build-isolation --wheel-dir dist .
        ${python}/bin/python -m pip install $pipInstallFlags .\
      '';
      installPhase = "true";
    });

    devShell = pkgs.mkShell {
      buildInputs = [
        # a drv with all dependencies without the main package
        (package.overrideAttrs (old: {
          src = ".";
        }))
      ];
    };
  in {
    packages.${defaultPackageName}.${defaultPackageVersion} = package;
    devShells.${defaultPackageName} = devShell;
  };
}
