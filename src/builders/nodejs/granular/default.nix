{
  jq,
  lib,
  makeWrapper,
  pkgs,
  python3,
  runCommand,
  stdenv,
  writeText,
  # dream2nix inputs
  builders,
  externals,
  utils,
  ...
}: {
  # Funcs
  # AttrSet -> Bool) -> AttrSet -> [x]
  getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
  getDependencies, # name: version: -> [ {name=; version=; } ]
  getSource, # name: version: -> store-path
  buildPackageWithOtherBuilder, # { builder, name, version }: -> drv
  # Attributes
  subsystemAttrs, # attrset
  defaultPackageName, # string
  defaultPackageVersion, # string
  packages, # list
  # attrset of pname -> versions,
  # where versions is a list of version strings
  packageVersions,
  # function which applies overrides to a package
  # It must be applied by the builder to each individual derivation
  # Example:
  #   produceDerivation name (mkDerivation {...})
  produceDerivation,
  # Custom Options: (parametrize builder behavior)
  # These can be passed by the user via `builderArgs`.
  # All options must provide default
  standalonePackageNames ? [],
  nodejs ? null,
  ...
} @ args: let
  b = builtins;

  nodejsVersion = subsystemAttrs.nodejsVersion;

  isMainPackage = name: version:
    (args.packages."${name}" or null) == version;

  nodejs =
    if args ? nodejs
    then args.nodejs
    else
      pkgs."nodejs-${builtins.toString nodejsVersion}_x"
      or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  nodeSources = runCommand "node-sources" {} ''
    tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
    mv node-* $out
  '';

  defaultPackage = allPackages."${defaultPackageName}"."${defaultPackageVersion}";

  allPackages =
    lib.mapAttrs
    (name: versions:
      lib.genAttrs
      versions
      (version:
        makePackage name version))
    packageVersions;

  outputs = {
    inherit defaultPackage;

    # select only the packages listed in dreamLock as main packages
    packages =
      b.foldl'
      (ps: p: ps // p)
      {}
      (lib.mapAttrsToList
        (name: version: {
          "${name}"."${version}" = allPackages."${name}"."${version}";
        })
        args.packages);
  };

  # This is only executed for electron based packages.
  # Electron ships its own version of node, requiring a rebuild of native
  # extensions.
  # Theoretically this requires headers for the exact electron version in use,
  # but we use the headers from nixpkgs' electron instead which might have a
  # different minor version.
  # Alternatively the headers can be specified via `electronHeaders`.
  # Also a custom electron version can be specified via `electronPackage`
  electron-rebuild = ''
    # prepare node headers for electron
    if [ -n "$electronPackage" ]; then
      export electronDist="$electronPackage/lib/electron"
    else
      export electronDist="$nodeModules/$packageName/node_modules/electron/dist"
    fi
    local ver
    ver="v$(cat $electronDist/version | tr -d '\n')"
    mkdir $TMP/$ver
    cp $electronHeaders $TMP/$ver/node-$ver-headers.tar.gz

    # calc checksums
    cd $TMP/$ver
    sha256sum ./* > SHASUMS256.txt
    cd -

    # serve headers via http
    python -m http.server 45034 --directory $TMP &

    # copy electron distribution
    cp -r $electronDist $TMP/electron
    chmod -R +w $TMP/electron

    # configure electron toolchain
    ${pkgs.jq}/bin/jq ".build.electronDist = \"$TMP/electron\"" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    ${pkgs.jq}/bin/jq ".build.linux.target = \"dir\"" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    ${pkgs.jq}/bin/jq ".build.npmRebuild = false" package.json \
        | ${pkgs.moreutils}/bin/sponge package.json

    # execute electron-rebuild if available
    export headers=http://localhost:45034/
    if command -v electron-rebuild &> /dev/null; then
      pushd $electronAppDir

      electron-rebuild -d $headers
      popd
    fi
  '';

  # Only executed for electron based packages.
  # Creates an executable script under /bin starting the electron app
  electron-wrap = ''
    mkdir -p $out/bin
    makeWrapper \
      $electronDist/electron \
      $out/bin/$(basename "$packageName") \
      --add-flags "$(realpath $electronAppDir)"
  '';

  # Generates a derivation for a specific package name + version
  makePackage = name: version: let
    deps = getDependencies name version;

    nodeDeps =
      lib.forEach
      deps
      (dep: allPackages."${dep.name}"."${dep.version}");

    dependenciesJson =
      b.toJSON
      (lib.listToAttrs
        (b.map
          (dep: lib.nameValuePair dep.name dep.version)
          deps));

    electronDep =
      if ! isMainPackage name version
      then null
      else
        lib.findFirst
        (dep: dep.name == "electron")
        null
        deps;

    electronVersionMajor =
      lib.versions.major electronDep.version;

    electronHeaders =
      if electronDep == null
      then null
      else pkgs."electron_${electronVersionMajor}".headers;

    pkg = produceDerivation name (stdenv.mkDerivation rec {
      inherit
        dependenciesJson
        electronHeaders
        nodeDeps
        nodeSources
        version
        ;

      packageName = name;

      pname = utils.sanitizeDerivationName name;

      installMethod = "symlink";

      electronAppDir = ".";

      # only run build on the main package
      runBuild = isMainPackage name version;

      src = getSource name version;

      nativeBuildInputs = [makeWrapper];

      buildInputs = [jq nodejs python3];

      # prevents running into ulimits
      passAsFile = ["dependenciesJson" "nodeDeps"];

      preConfigurePhases = ["d2nLoadFuncsPhase" "d2nPatchPhase"];

      # can be overridden to define alternative install command
      # (defaults to 'npm run postinstall')
      buildScript = null;

      # python script to modify some metadata to support installation
      # (see comments below on d2nPatchPhase)
      fixPackage = "${./fix-package.py}";

      # script to install (symlink or copy) dependencies.
      installDeps = "${./install-deps.py}";

      # costs performance and doesn't seem beneficial in most scenarios
      dontStrip = true;

      # declare some useful shell functions
      d2nLoadFuncsPhase = ''
        # function to resolve symlinks to copies
        symlinksToCopies() {
          local dir="$1"

          echo "transforming symlinks to copies..."
          for f in $(find -L "$dir" -xtype l); do
            if [ -f $f ]; then
              continue
            fi
            echo "copying $f"
            chmod +wx $(dirname "$f")
            mv "$f" "$f.bak"
            mkdir "$f"
            if [ -n "$(ls -A "$f.bak/")" ]; then
              cp -r "$f.bak"/* "$f/"
              chmod -R +w $f
            fi
            rm "$f.bak"
          done
        }
      '';

      # TODO: upstream fix to nixpkgs
      # example which requires this:
      #   https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
      unpackCmd =
        if lib.hasSuffix ".tgz" src
        then "tar --delay-directory-restore -xf $src"
        else null;

      unpackPhase = ''
        runHook preUnpack

        nodeModules=$out/lib/node_modules

        export sourceRoot="$nodeModules/$packageName"

        # sometimes tarballs do not end with .tar.??
        unpackFallback(){
          local fn="$1"
          tar xf "$fn"
        }

        unpackCmdHooks+=(unpackFallback)

        unpackFile $src

        # Make the base dir in which the target dependency resides in first
        mkdir -p "$(dirname "$sourceRoot")"

        # install source
        if [ -f "$src" ]
        then
            # Figure out what directory has been unpacked
            export packageDir="$(find . -maxdepth 1 -type d | tail -1)"

            # Restore write permissions
            find "$packageDir" -type d -exec chmod u+x {} \;
            chmod -R u+w "$packageDir"

            # Move the extracted tarball into the output folder
            mv "$packageDir" "$sourceRoot"
        elif [ -d "$src" ]
        then
            export strippedName="$(stripHash $src)"

            # Restore write permissions
            chmod -R u+w "$strippedName"

            # Move the extracted directory into the output folder
            mv "$strippedName" "$sourceRoot"
        fi

        runHook postUnpack
      '';

      # The python script wich is executed in this phase:
      #   - ensures that the package is compatible to the current system
      #   - ensures the main version in package.json matches the expected
      #   - pins dependency versions in package.json
      #     (some npm commands might otherwise trigger networking)
      #   - creates symlinks for executables declared in package.json
      # Apart from that:
      #   - Any usage of 'link:' in package.json is replaced with 'file:'
      #   - If package-lock.json exists, it is deleted, as it might conflict
      #     with the parent package-lock.json.
      d2nPatchPhase = ''
        # delete package-lock.json as it can lead to conflicts
        rm -f package-lock.json

        # repair 'link:' -> 'file:'
        mv $nodeModules/$packageName/package.json $nodeModules/$packageName/package.json.old
        cat $nodeModules/$packageName/package.json.old | sed 's!link:!file\:!g' > $nodeModules/$packageName/package.json
        rm $nodeModules/$packageName/package.json.old

        # run python script (see comment above):
        cp package.json package.json.bak
        python $fixPackage \
        || \
        # exit code 3 -> the package is incompatible to the current platform
        #  -> Let the build succeed, but don't create lib/node_packages
        if [ "$?" == "3" ]; then
          rm -r $out/*
          echo "Not compatible with system $system" > $out/error
          exit 0
        else
          exit 1
        fi

        # configure typescript
        if [ -f ./tsconfig.json ] \
            && node -e 'require("typescript")' &>/dev/null; then
          node ${./tsconfig-to-json.js}
          ${pkgs.jq}/bin/jq ".compilerOptions.preserveSymlinks = true" tsconfig.json \
              | ${pkgs.moreutils}/bin/sponge tsconfig.json
        fi
      '';

      # - installs dependencies into the node_modules directory
      # - adds executables of direct node module dependencies to PATH
      # - adds the current node module to NODE_PATH
      # - sets HOME=$TMPDIR, as this is required by some npm scripts
      # TODO: don't install dev dependencies. Load into NODE_PATH instead
      configurePhase = ''
        runHook preConfigure

        # symlink sub dependencies as well as this imitates npm better
        python $installDeps

        # add bin path entries collected by python script
        if [ -e $TMP/ADD_BIN_PATH ]; then
          export PATH="$PATH:$(cat $TMP/ADD_BIN_PATH)"
        fi

        # add dependencies to NODE_PATH
        export NODE_PATH="$NODE_PATH:$nodeModules/$packageName/node_modules"

        export HOME=$TMPDIR

        runHook postConfigure
      '';

      # Runs the install command which defaults to 'npm run postinstall'.
      # Allows using custom install command by overriding 'buildScript'.
      buildPhase = ''
        runHook preBuild

        # execute electron-rebuild
        if [ -n "$electronHeaders" ]; then
          ${electron-rebuild}
        fi

        # execute install command
        if [ -n "$buildScript" ]; then
          if [ -f "$buildScript" ]; then
            $buildScript
          else
            eval "$buildScript"
          fi
        # by default, only for top level packages, `npm run build` is executed
        elif [ -n "$runBuild" ] && [ "$(jq '.scripts.build' ./package.json)" != "null" ]; then
          npm run build
        else
          if [ "$(jq '.scripts.install' ./package.json)" != "null" ]; then
            npm --production --offline --nodedir=$nodeSources run install
          fi
          if [ "$(jq '.scripts.postinstall' ./package.json)" != "null" ]; then
            npm --production --offline --nodedir=$nodeSources run postinstall
          fi
        fi

        runHook postBuild
      '';

      # Symlinks executables and manual pages to correct directories
      installPhase = ''
        runHook preInstall

        echo "Symlinking exectuables to /bin"
        if [ -d "$nodeModules/.bin" ]
        then
          chmod +x $nodeModules/.bin/*
          ln -s $nodeModules/.bin $out/bin
        fi

        echo "Symlinking manual pages"
        if [ -d "$nodeModules/$packageName/man" ]
        then
          mkdir -p $out/share
          for dir in "$nodeModules/$packageName/man/"*
          do
            mkdir -p $out/share/man/$(basename "$dir")
            for page in "$dir"/*
            do
                ln -s $page $out/share/man/$(basename "$dir")
            done
          done
        fi

        # wrap electron app
        # execute electron-rebuild
        if [ -n "$electronHeaders" ]; then
          ${electron-wrap}
        fi

        runHook postInstall
      '';
    });
  in
    pkg;
in
  outputs
