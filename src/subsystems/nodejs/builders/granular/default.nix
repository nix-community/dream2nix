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

    nodejsVersion = subsystemAttrs.nodejsVersion or null;
    transitiveBinaries = subsystemAttrs.transitiveBinaries or false;

    isMainPackage = name: version:
      (args.packages."${name}" or null) == version;

    nodejs =
      if args ? nodejs
      then args.nodejs
      else if nodejsVersion != null
      then
        pkgs."nodejs-${builtins.toString nodejsVersion}_x"
        or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs")
      else pkgs.nodejs;

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
      jq ".build.electronDist = \"$TMP/electron\" | .build.linux.target = \"dir\" | .build.npmRebuild = false" package.json > package.json.tmp
      mv package.json.tmp package.json

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
    electronBin =
      if pkgs.stdenv.isLinux
      then "$electronDist/electron"
      else "$electronDist/Electron.app/Contents/MacOS/Electron";

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
              s = p.extraInfo;
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
            s = dep.extraInfo;
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

      hasExtraInfo = subsystemAttrs ? extraInfo;
      extraInfo = subsystemAttrs.extraInfo.${name}.${version} or {};
      # If the translator doesn't provide extraInfo, assume scripts
      hasInstall =
        if hasExtraInfo
        then extraInfo.hasInstallScript or false
        else true;
      isMain = isMainPackage name version;

      pkg = produceDerivation name (stdenv.mkDerivation rec {
        inherit
          dependenciesJson
          electronHeaders
          version
          transitiveBinaries
          prodModules
          ;

        packageName = name;

        inherit pname;

        passthru.dependencies = passthruDeps;

        passthru.devShell = import ./devShell.nix {
          inherit mkShell nodejs devModules;
        };

        passthru.extraInfo = extraInfo;

        /*
        For top-level packages install dependencies as full copies, as this
        reduces errors with build tooling that doesn't cope well with
        symlinking.
        */
        # TODO implement copy and make configurable
        # installMethod =
        #   if isMain
        #   then "copy"
        #   else "symlink";

        electronAppDir = ".";

        # only run build on the main package
        runBuild = isMain && (subsystemAttrs.hasBuildScript or true);

        # can be overridden to define alternative install command
        # (defaults to npm install steps)
        buildScript = null;
        shouldBuild = hasInstall || runBuild || buildScript != null || electronHeaders != null;
        buildModules =
          if runBuild
          then devModules
          else prodModules;
        nodeSources =
          if shouldBuild
          then nodejs
          else null;

        # We don't need unpacked sources
        src = let t = getSource name version; in t.original or t;

        nativeBuildInputs =
          if shouldBuild
          then [makeWrapper]
          else [];

        # We must provide nodejs even when not building to allow
        # patchShebangs to find it for binaries
        buildInputs =
          if shouldBuild || (!hasExtraInfo || (extraInfo ? bin))
          then [jq nodejs python3]
          else [python3];

        # prevents running into ulimits
        passAsFile = ["dependenciesJson"];

        preConfigurePhases = ["d2nLoadFuncsPhase" "d2nPatchPhase"];

        # python script to modify some metadata to support installation
        # (see comments below on d2nPatchPhase)
        fixPackage = "${./fix-package.py}";
        linkBins = "${./link-bins.py}";

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

        # https://github.com/NixOS/nixpkgs/pull/50961#issuecomment-449638192
        # example which requires this:
        #   https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
        TAR_OPTIONS = "--delay-directory-restore";

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

              # Ensure write + directory execute permissions
              chmod -R u+w,a+X -- "$packageDir"

              # Move the extracted tarball into the output folder
              mv -- "$packageDir" "$sourceRoot"
          elif [ -d "$src" ]
          then
              export strippedName="$(stripHash $src)"

              # Ensure write + directory execute permissions
              chmod -R u+w,a+X -- "$strippedName"

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

          if [ -n "$buildModules" ]; then
            if [ -L $sourceRoot/node_modules ] || [ -e $sourceRoot/node_modules ]; then
              echo Warning: The source $sourceRoot includes a node_modules directory. Replacing. >&2
              rm -rf $sourceRoot/node_modules
            fi
            ln -s $buildModules $sourceRoot/node_modules
            if [ -d $buildModules/.bin ]; then
              export PATH="$PATH:$sourceRoot/node_modules/.bin"
            fi
          fi
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
        # for installing, we only need to run `npm run install` (pre and post scripts run automatically)
        # https://github.com/npm/npm/issues/5919
        # TODO build first if has build, give it devModules during build

        buildPhase =
          if shouldBuild
          then ''
            set -x
            runHook preBuild

            if [ -n "$shouldBuild" ]; then
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
              else
                if [ -n "$runBuild" ]; then
                  # by default, only for top level packages, `npm run build` is executed
                  npm run --if-present build
                fi

                # This seems to be the only script that needs running on install
                npm --omit=dev --offline --nodedir=$nodeSources run --if-present install
              fi
            fi

            runHook postBuild
            set +x
          ''
          else "true";

        # Symlinks executables and manual pages to correct directories
        installPhase = ''
          runHook preInstall

          if [ "$buildModules" != "$prodModules" ]; then
            if [ -n "$prodModules" ]; then
              ln -sf $prodModules $sourceRoot/node_modules
            else
              rm $sourceRoot/node_modules
            fi
          fi

          echo "Symlinking bin entries from package.json"
          python $linkBins

          if [ -n "$transitiveBinaries" ]; then
            # pass down transitive binaries, like npm does
            # all links are absolute so we can just copy
            cp -af --no-preserve=mode $prodModules/.bin/. $out/bin/.
          fi

          if rmdir $out/bin 2>/dev/null; then
            # we didn't install any binaries
            rm $nodeModules/.bin
          else
            # make sure binaries are executable, following symlinks
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
            mkdir -p $out/bin
            makeWrapper \
              ${electronBin} \
              $out/bin/$(basename "$packageName") \
              --add-flags "$(realpath $electronAppDir)"
          fi

          runHook postInstall
        '';
      });
    in
      pkg;
  in
    outputs;
}
