{...}: {
  type = "pure";

  build = {
    jq,
    lib,
    makeWrapper,
    mkShell,
    pkgs,
    python3,
    runCommandLocal,
    stdenv,
    writeText,
    ...
  }: {
    # Funcs
    # name: version: -> helpers
    getCyclicHelpers,
    # name: version: -> [ {name=; version=; } ]
    getDependencies,
    # name: version: -> store-path
    getSource,
    # name: version: -> {type="git"; url=""; hash="";} + extra values from npm packages
    getSourceSpec,
    # Attributes
    # attrset
    subsystemAttrs,
    # string
    defaultPackageName,
    # string
    defaultPackageVersion,
    # list
    packages,
    # attrset of pname -> versions,
    # where versions is a list of version strings
    packageVersions,
    # function which applies overrides to a package
    # It must be applied by the builder to each individual derivation
    # Example:
    #   produceDerivation name (mkDerivation {...})
    produceDerivation,
    nodejs ? null,
    ...
  } @ args: let
    b = builtins;
    l = lib // builtins;

    nodejsVersion = subsystemAttrs.nodejsVersion;

    isMainPackage = name: version:
      (args.packages."${name}" or null) == version;

    nodejs =
      args.nodejs
      or (
        pkgs."nodejs-${builtins.toString nodejsVersion}_x"
        or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs")
      );

    nodeSources = runCommandLocal "node-sources" {} ''
      tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
      mv node-* $out
    '';

    allPackages =
      lib.mapAttrs
      (name: versions:
        lib.genAttrs
        versions
        (version:
          makePackage name version))
      packageVersions;

    outputs = rec {
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

      devShell = devShells.default;

      devShells =
        {default = devShells.${defaultPackageName};}
        // (
          l.mapAttrs
          (name: version: allPackages.${name}.${version}.devShell)
          args.packages
        );
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
      cp --no-preserve=mode $electronHeaders $TMP/$ver/node-$ver-headers.tar.gz

      # calc checksums
      cd $TMP/$ver
      sha256sum ./* > SHASUMS256.txt
      cd -

      # serve headers via http
      python -m http.server 45034 --directory $TMP &

      # copy electron distribution
      cp -r --no-preserve=mode $electronDist $TMP/electron

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
    electron-wrap =
      if pkgs.stdenv.isLinux
      then ''
        mkdir -p $out/bin
        makeWrapper \
          $electronDist/electron \
          $out/bin/$(basename "$packageName") \
          --add-flags "$(realpath $electronAppDir)"
      ''
      else ''
        mkdir -p $out/bin
        makeWrapper \
          $electronDist/Electron.app/Contents/MacOS/Electron \
          $out/bin/$(basename "$packageName") \
          --add-flags "$(realpath $electronAppDir)"
      '';

    # Generates a derivation for a specific package name + version
    makePackage = name: version: let
      pname = name;

      rawDeps = getDependencies name version;
      inherit (getCyclicHelpers name version) cycleeDeps cyclicParent isCyclee isThisCycleeFor replaceCyclees;

      # cycles
      # for nodejs, we need to copy any cycles into a single package together
      # getCyclicHelpers already cut the cycles for us, into one cyclic (e.g. eslint) and many cyclee (e.g. eslint-util)
      # when a package is cyclic:
      # - the cyclee deps should not be in the cyclic/node_modules folder
      # - the cyclee deps need to be copied into the package next to cyclic
      #   so node can find them all together
      # when a package is cyclee:
      # - the cyclic dep should not be in the cyclee/node_modules folder
      # when a dep is cyclee:
      # - the dep path should point into the cyclic parent

      # Keep only the deps we can install, assume it all works out
      deps = let
        myOS = with stdenv.targetPlatform;
          if isLinux
          then "linux"
          else if isDarwin
          then "darwin"
          else "";
      in
        replaceCyclees (lib.filter
          (
            dep: let
              p = allPackages."${dep.name}"."${dep.version}";
              s = p.sourceInfo;
            in
              # this dep is a cyclee
              !(isCyclee dep.name dep.version)
              # this dep is not for this os
              && ((s.os or null == null) || lib.any (o: o == myOS) s.os)
              # this package is a cyclee
              && !(isThisCycleeFor dep.name dep.version)
          )
          rawDeps);

      nodePkgs =
        l.map
        (dep: let
          pkg = allPackages."${dep.name}"."${dep.version}";
        in
          if dep ? replaces
          then pkg // {packageName = dep.replaces.name;}
          else pkg)
        deps;
      cycleePkgs =
        l.map
        (dep: allPackages."${dep.name}"."${dep.version}")
        cycleeDeps;

      # Derivation building the ./node_modules directory in isolation.
      makeModules = {
        withDev ? false,
        withOptionals ? true,
      }: let
        isMain = isMainPackage name version;
        # These flags will only be present if true. Also, dev deps are required for non-main packages
        myDeps =
          lib.filter
          (dep: let
            s = dep.sourceInfo;
          in
            (withOptionals || !(s.optional or false))
            && (!isMain || (withDev || !(s.dev or false))))
          nodePkgs;
      in
        if lib.length myDeps == 0
        then null
        else
          pkgs.runCommandLocal "node_modules-${pname}" {} ''
            shopt -s nullglob
            set -e

            mkdir $out

            function doLink() {
              local name=$(basename $1)
              local target="$2/$name"
              if [ -e "$target" ]; then
                local link=$(readlink $target)
                if [ "$link" = $1 ]; then
                  # cyclic dep, all ok
                  return
                fi
                echo "Cannot overwrite $target (-> $link) with $1 - incorrect cycle! Versions issue?" >&2
                exit 1
              fi
              ln -s $1 $target
            }

            function linkDep() {
              local pkg=$1
              local name=$2
              # special case for namespaced modules
              if [[ $name == @* ]]; then
                local namespace=$(dirname $name)
                mkdir -p $out/$namespace
                doLink $pkg/lib/node_modules/$name $out/$namespace
              else
                doLink $pkg/lib/node_modules/$name $out
              fi
            }

            ${l.toString (l.map
              (d: "linkDep ${l.toString d} ${d.packageName}\n")
              myDeps)}

            # symlink module executables to ./node_modules/.bin
            mkdir $out/.bin
            for dep in ${l.toString myDeps}; do
              # We assume dotfiles are not public binaries
              for b in $dep/bin/*; do
                if [ -L "$b" ]; then
                  # when these relative symlinks, make absolute
                  # last one wins (-sf)
                  ln -sf $(readlink -f $b) $out/.bin/$(basename $b)
                else
                  # e.g. wrapped binary
                  ln -sf $b $out/.bin/$(basename $b)
                fi
              done
            done
            # remove empty .bin
            rmdir $out/.bin || true
          '';
      prodModules = makeModules {withDev = false;};
      # if noDev was used, these are just the prod modules
      devModules = makeModules {withDev = true;};

      # TODO why is this needed? Seems to work without
      passthruDeps =
        l.listToAttrs
        (l.forEach deps
          (dep:
            l.nameValuePair
            dep.name
            allPackages."${dep.name}"."${dep.version}"));

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
        if
          (electronDep == null)
          # hashes seem unavailable for electron < 4
          || ((l.toInt electronVersionMajor) <= 2)
        then null
        else pkgs."electron_${electronVersionMajor}".headers;

      pkg = produceDerivation name (stdenv.mkDerivation rec {
        inherit
          dependenciesJson
          electronHeaders
          nodeSources
          version
          ;

        packageName = name;

        inherit pname;

        # TODO why is this needed? It works without it?
        # passthru.dependencies = passthruDeps;

        passthru.devShell = import ./devShell.nix {
          inherit mkShell nodejs devModules;
        };

        /*
        For top-level packages install dependencies as full copies, as this
        reduces errors with build tooling that doesn't cope well with
        symlinking.
        */
        # TODO implement copy and make configurable
        # installMethod =
        #   if isMainPackage name version
        #   then "copy"
        #   else "symlink";

        electronAppDir = ".";

        # only run build on the main package
        runBuild = isMainPackage name version;

        src = getSource name version;

        nativeBuildInputs = [makeWrapper];

        buildInputs = [jq nodejs python3];

        # prevents running into ulimits
        passAsFile = ["dependenciesJson"];

        preConfigurePhases = ["d2nLoadFuncsPhase" "d2nPatchPhase"];

        # can be overridden to define alternative install command
        # (defaults to 'npm run postinstall')
        buildScript = null;

        # python script to modify some metadata to support installation
        # (see comments below on d2nPatchPhase)
        fixPackage = "${./fix-package.py}";

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
              l=$(readlink -f $f)
              rm -f "$f"
              cp -r --no-preserve=mode "$l" "$f"
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

              # TODO why is this needed?
              # find "$packageDir" -type d -exec chmod u+x {} \;
              # Restore write permissions
              chmod -R u+w -- "$packageDir"

              # Move the extracted tarball into the output folder
              mv -- "$packageDir" "$sourceRoot"
          elif [ -d "$src" ]
          then
              export strippedName="$(stripHash $src)"

              # Restore write permissions
              chmod -R u+w -- "$strippedName"

              # Move the extracted directory into the output folder
              mv -- "$strippedName" "$sourceRoot"
          fi

          # provide bin, we'll remove it if unused
          mkdir $out/bin
          # We keep the binaries in /bin but node uses .bin
          # Symlink so that wrapper scripts etc work
          ln -s ../../bin $nodeModules/.bin

          runHook postUnpack
        '';

        # The python script wich is executed in this phase:
        #   - ensures that the package is compatible to the current system
        #     (if not already filtered above with os prop from translator)
        #   - ensures the main version in package.json matches the expected
        #   - pins dependency versions in package.json
        #     (some npm commands might otherwise trigger networking)
        #   - creates symlinks for executables declared in package.json
        #   - Any usage of 'link:' in deps will be replaced with the exact version
        # Apart from that:
        #   - If package-lock.json exists, it is deleted, as it might conflict
        #     with the parent package-lock.json.
        d2nPatchPhase = ''
          # delete package-lock.json as it can lead to conflicts
          rm -f package-lock.json

          # run python script (see comment above):
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
        '';

        # - links dependencies into the node_modules directory + adds bin to PATH
        # - sets HOME=$TMPDIR, as this is required by some npm scripts
        configurePhase = ''
          runHook preConfigure

          ${
            if prodModules != null
            then ''
              if [ -L $sourceRoot/node_modules ] || [ -e $sourceRoot/node_modules ]; then
                echo Warning: The source $sourceRoot includes a node_modules directory. Replacing. >&2
                rm -rf $sourceRoot/node_modules
              fi
              ln -s ${prodModules} $sourceRoot/node_modules
              if [ -d ${prodModules}/.bin ]; then
                export PATH="$PATH:$sourceRoot/node_modules/.bin"
              fi
            ''
            else ""
          }
          ${
            # Here we copy cyclee deps into the cyclehead node_modules
            # so the cyclic deps can find each other
            if cycleePkgs != []
            then ''
              for dep in ${l.toString cycleePkgs}; do
                # We must copy everything so Node finds it
                # Let's hope that clashing names are just duplicates
                # keep write perms with no-preserve
                cp -rf --no-preserve=mode $dep/lib/node_modules/* $nodeModules
                if [ -d $dep/bin ]; then
                  # this copies symlinks as-is, so they will point to the
                  # local target when relative, and module-local links
                  # are made relative by nixpkgs post-build
                  # last one wins (-f)
                  cp -af --no-preserve=mode $dep/bin/. $out/bin/.
                fi
              done
            ''
            else ""
          }

          export HOME=$TMPDIR

          runHook postConfigure
        '';

        # Runs the install command which defaults to 'npm run postinstall'.
        # Allows using custom install command by overriding 'buildScript'.
        # TODO this logic supposes a build script, which is not documented
        buildPhase = ''
          runHook preBuild

          # execute electron-rebuild
          if [ -n "$electronHeaders" ]; then
            echo "executing electron-rebuild"
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
            npm --omit=dev --offline --nodedir=$nodeSources run --if-present preinstall
            npm --omit=dev --offline --nodedir=$nodeSources run --if-present install
            npm --omit=dev --offline --nodedir=$nodeSources run --if-present postinstall
          fi

          runHook postBuild
        '';

        # Symlinks executables and manual pages to correct directories
        installPhase = ''
          runHook preInstall

          if rmdir $out/bin 2>/dev/null; then
            # we didn't install any binaries
            rm $nodeModules/.bin
          else
            # make sure binaries are executable - follows symlinks
            # ignore failures from symlinks pointing to other pkgs
            chmod a+x $out/bin/* 2>/dev/null || true
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
          if [ -n "$electronHeaders" ]; then
            echo "Wrapping electron app"
            ${electron-wrap}
          fi

          runHook postInstall
        '';
      });
    in
      pkg
      // {sourceInfo = getSourceSpec name version;};
  in
    outputs;
}
