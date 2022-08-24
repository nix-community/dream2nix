{...}: {
  type = "pure";

  build = {
    lib,
    pkgs,
    stdenv,
    # dream2nix inputs
    externals,
    ...
  }: {
    ### FUNCTIONS
    # AttrSet -> Bool) -> AttrSet -> [x]
    getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
    getDependencies, # name: version: -> [ {name=; version=; } ]
    getSource, # name: version: -> store-path
    # to get information about the original source spec
    getSourceSpec, # name: version: -> {type="git"; url=""; hash="";}
    ### ATTRIBUTES
    subsystemAttrs, # attrset
    defaultPackageName, # string
    defaultPackageVersion, # string
    # all exported (top-level) package names and versions
    # attrset of pname -> version,
    packages,
    # all existing package names and versions
    # attrset of pname -> versions,
    # where versions is a list of version strings
    packageVersions,
    # function which applies overrides to a package
    # It must be applied by the builder to each individual derivation
    # Example:
    #   produceDerivation name (mkDerivation {...})
    produceDerivation,
    ...
  } @ args: let
    l = lib // builtins;

    allDependencySources' =
      l.flatten
      (l.mapAttrsToList
        (name: versions:
          if
            l.elem name [
              defaultPackageName
              "libc6"
            ]
          then []
          else l.map (ver: getSource name ver) versions)
        packageVersions);

    allDependencySources =
      l.map
      (src: src.original or src)
      allDependencySources';

    package = produceDerivation defaultPackageName (stdenv.mkDerivation {
      name = defaultPackageName;
      src = ":";
      dontUnpack = true;
      buildInputs = [pkgs.unzip];
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      doCheck = false;
      dontStrip = true;
      buildPhase = ''
        runHook preBuild

        mkdir -p $out/bin
        mkdir -p $out/share
        mkdir -p $out/lib
        mkdir -p $out/etc

        for file in ${toString allDependencySources};do
          mkdir -p $TMP/unpack
          # unzip -d $TMP/unpack $file
          cd $TMP/unpack
          ar vx $file
          tar xvf $TMP/unpack/data.tar.xz

          echo $file

          for variant in "bin" "sbin" "games"; do
            if [[ -d $TMP/unpack/usr/$variant && -n "$(ls -A $TMP/unpack/usr/$variant)" ]]; then
            echo "Copying usr/$variant"
            cp -r $TMP/unpack/usr/$variant/* $out/bin
            fi
          done

          echo "Copying usr/share"
          if [ -d $TMP/unpack/usr/share ]; then
          cp -r $TMP/unpack/usr/share/* $out/share
          fi


          for variant in "/usr/lib" "/usr/lib64" "/lib" "/lib64"; do
            for file in $(find $TMP/unpack/$variant -type f -or -type l);do
              cp -r $file $out/lib
            done
          done

          mkdir -p $TMP/unpack/etc
          cp -r $TMP/unpack/etc $out
          rm -rf $TMP/unpack
        done

        runHook postBuild
      '';
      installPhase = ":";
      # autoPatchelfIgnoreMissingDeps = true;
    });
  in {
    packages.${defaultPackageName}.${defaultPackageVersion} = package;
  };
}
