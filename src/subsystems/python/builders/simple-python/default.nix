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
          if l.elem name [defaultPackageName "setuptools" "pip"]
          then []
          else l.map (ver: getSource name ver) versions)
        packageVersions);

    allDependencySources =
      l.map
      (src: src.original or src)
      allDependencySources';

    buildReq = subsystemAttrs.buildRequires or {};
    requirementsFiles = subsystemAttrs.requirementsFiles or {};
    buildReqArgs = l.concatStringsSep " " (l.map (name: "${name}==${buildReq.${name}}") (l.attrNames buildReq));
    # Requirements files may contain hashes and markers; we let pip handle
    # these. As a fallback we support a [ { name = 'foo'; version = '1.2.3'; },
    # ... ] list which we might want to generate from the deps stored in
    # dreamlock already.
    reqArgs =
      if requirementsFiles != {}
      then l.concatStringsSep " " (l.map (x: "-r ${x}") requirementsFiles)
      else l.concatStringsSep " " (l.map (x: "${x.name}==${x.version}") subsystemAttrs.reqList or []);

    package = produceDerivation defaultPackageName (buildFunc {
      name = defaultPackageName;
      src = getSource defaultPackageName defaultPackageVersion;
      format = subsystemAttrs.packageFormat or "setuptools";
      buildInputs = pkgs.pythonManylinuxPackages.manylinux1;
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      propagatedBuildInputs = [python.pkgs.setuptools];
      doCheck = false;
      dontStrip = true;
      preBuild =
        ''
          mkdir dist
          for file in ${builtins.toString allDependencySources}; do
            # pick right most element of path
            fname=''${file##*/}
            fname=$(stripHash $fname)
            cp $file dist/$fname
          done
          mkdir -p "$out/${python.sitePackages}"
          export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"
        ''
        + (
          if buildReq != {}
          then ''
            ${python}/bin/python -m pip install ${buildReqArgs} \
              --find-links ./dist/ \
              --no-build-isolation \
              --no-index \
              --no-warn-script-location \
              --prefix="$out" \
              --no-cache \
              $pipInstallFlags
          ''
          else ""
        )
        + ''
          ${python}/bin/python -m pip install ${reqArgs} \
            --find-links ./dist/ \
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
  };
}
