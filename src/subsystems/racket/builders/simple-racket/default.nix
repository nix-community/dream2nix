{
  pkgs,
  lib,
  externals,
  ...
}: {
  type = "pure";

  build = {
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

    # packages to export
    exportedPackages =
      {default = exportedPackages.${defaultPackageName};}
      // (lib.mapAttrs
        (name: version: {
          "${version}" = buildRacketWithPackages name;
        })
        args.packages);

    allPackageSourceAttrs = l.pipe packageVersions [
      (l.mapAttrsToList (name: versions: (l.map
        (ver: let
          src = getSource name ver;
          srcDir = src.original or src;
        in
          l.nameValuePair name srcDir)
        versions)))
      l.flatten
      l.listToAttrs
    ];

    # Many of the details mimic https://github.com/Warbo/nix-helpers,
    # the license of which permits copying as long as we don't try to
    # patent anything.
    buildRacketWithPackages = name:
      produceDerivation "racket-with-${name}-env"
      (pkgs.runCommandCC "racket-with-${name}-env"
        {
          inherit (pkgs) racket;
          buildInputs = with pkgs; [makeWrapper racket];
        } ''
          ${l.toShellVars {"allDepSrcs" = allPackageSourceAttrs;}}

          mkdir -p $TMP/unpack

          for p in ''${!allDepSrcs[@]}
          do
            mkdir $TMP/unpack/$p
            cp -R ''${allDepSrcs[$p]}/. $TMP/unpack/$p
          done

          export PLTCONFIGDIR=$out/etc
          mkdir -p $PLTCONFIGDIR

          cp $racket/etc/racket/config.rktd $PLTCONFIGDIR

          $racket/bin/racket -t ${./make-new-config.rkt}

          export TMP_RACO_HOME=$out/tmp-raco-home
          mkdir -p $TMP_RACO_HOME

          chmod +w -R $TMP/unpack
          HOME=$TMP_RACO_HOME $racket/bin/raco pkg install --copy $(ls -d $TMP/unpack/*/)

          for SUBPATH in $(ls -d $TMP_RACO_HOME/.local/share/racket/*/); # there is only one SUBPATH (whose name is the version number of Racket)
          do
              cp -r -t $PLTCONFIGDIR $SUBPATH/*
          done

          rm -rf $TMP_RACO_HOME

          mkdir -p $out/bin
          for EXE in $racket/bin/* $out/etc/bin/*;
          do
            NAME=$(basename "$EXE")
            makeWrapper "$EXE" "$out/bin/$NAME" --set PLTCONFIGDIR "$PLTCONFIGDIR"
          done
        '');
  in {
    packages = exportedPackages;
  };
}
