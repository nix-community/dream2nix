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
          if l.elem name [defaultPackageName]
          then []
          else l.map (ver: getSource name ver) versions)
        packageVersions);

    allDependencySources =
      l.map
      (src: l.trace (l.toJSON src) l.trace (l.toJSON src.original) src.original)
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

        mkdir $out/bin
        mkdir $out/share
        mkdir $out/lib
        mkdir $out/etc

        for file in ${toString allDependencySources};do
          mkdir $TMP/unpack
          unzip -d $TMP/unpack file
          cd $TMP/unpack
          tar -xf $TMP/unpack/data.tar.xz
          cp $TMP/unpack/usr/bin/* $out/bin
          cp $TMP/unpack/usr/sbin/* $out/bin
          cp -r $TMP/unpack/usr/share/* $out/share
          cp -r $TMP/unpack/etc/* $out/etc

        runHook postBuild
      '';
    });
  in {
    packages.${defaultPackageName}.${defaultPackageVersion} = package;
  };
}
