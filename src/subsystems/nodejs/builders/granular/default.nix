{...}: {
  type = "pure";

  build = {
    jq,
    lib,
    makeWrapper,
    pkgs,
    python3,
    runCommandLocal,
    stdenv,
    writeText,
    ...
  }: {
    # Funcs
    # AttrSet -> Bool) -> AttrSet -> [x]
    # name: version: -> [ {name=; version=; } ]
    getCyclicDependencies,
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
      if args ? nodejs
      then args.nodejs
      else
        pkgs."nodejs-${builtins.toString nodejsVersion}_x"
        or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

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

      # Keep only the deps we can install, assume it all works out
      deps = let
        myOS = with stdenv.targetPlatform;
          if isLinux
          then "linux"
          else if isDarwin
          then "darwin"
          else "";
      in
        lib.filter (
          dep: let
            p = allPackages."${dep.name}"."${dep.version}";
            s = p.sourceInfo;
          in
            !(s ? os) || lib.any (o: o == myOS) s.os
        )
        rawDeps;

      nodeDeps =
        builtins.map
        (dep: allPackages."${dep.name}"."${dep.version}")
        deps;

      # Derivation building the ./node_modules directory in isolation.
      makeModules = {
        withDev ? false,
        withOptionals ? true,
      }: let
        isMain = isMainPackage name version;
        # These flags will only be present if true. Also, dev deps are required for non-main packages
        myDeps = lib.filter (dep: let
          s = dep.sourceInfo;
        in
          (withOptionals || !(s ? optional))
          && (!isMain || (withDev || !(s ? dev))))
        nodeDeps;
      in
        if lib.length myDeps == 0
        then null
        else
          pkgs.runCommandLocal "node_modules-${pname}" {} ''
            shopt -s nullglob
            mkdir $out
            for pkg in ${l.toString myDeps}; do
              if [ -d $pkg/lib/node_modules/ ]; then
                cd $pkg/lib/node_modules/
                for dir in *; do
                  # special case for namespaced modules
                  if [[ $dir == @* ]]; then
                    mkdir -p $out/$dir
                    ln -s $pkg/lib/node_modules/$dir/* $out/$dir/
                  else
                    ln -s $pkg/lib/node_modules/$dir $out/
                  fi
                done
              fi
            done

            # symlink module executables to ./node_modules/.bin
            mkdir $out/.bin
            for dep in ${l.toString myDeps}; do
              for b in $dep/bin/*; do
                # these are all relative symlinks, make absolute; Nix post build will make relative
                # last one wins (-f)
                ln -sf $dep/bin/$(readlink $b) $out/.bin/$(basename $b)
              done
            done
          '';
      prodModules = makeModules {withDev = false;};
      devModules = makeModules {withDev = true;};

      # passthruDeps =
      #   l.listToAttrs
      #   (l.forEach deps
      #     (dep:
      #       l.nameValuePair
      #       dep.name
      #       allPackages."${dep.name}"."${dep.version}"));

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
          nodeSources
          version
          ;

        packageName = name;

        inherit pname;

        # passthru.dependencies = passthruDeps;

        passthru.devShell = pkgs.mkShell {
          path = [nodejs];
          buildInputs = [nodejs];
          shellHook =
            if devModules != null
            then ''
              # create the ./node_modules directory
              if [ -e ./node_modules ] && [ ! -L ./node_modules ]; then
                echo -e "\nFailed creating the ./node_modules symlink to '${devModules}'"
                echo -e "\n./node_modules already exists and is a directory, which means it is managed by another program. Please delete ./node_modules first and re-enter the dev shell."
              else
                rm -f ./node_modules
                ln -s ${devModules} ./node_modules
                export PATH="$PATH:$(realpath ./node_modules)/.bin"
              fi
            ''
            else "";
        };

        installMethod = "symlink";

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

          runHook postUnpack
        '';

        # The python script wich is executed in this phase:
        #   - ensures that the package is compatible to the current system (but already filtered above with os)
        #   - ensures the main version in package.json matches the expected
        #   - pins dependency versions in package.json
        #     (some npm commands might otherwise trigger networking)
        #   - creates symlinks for executables declared in package.json in $out/bin
        # Apart from that:
        #   - Any usage of 'link:' in package.json is replaced with 'file:'
        #   - If package-lock.json exists, it is deleted, as it might conflict
        #     with the parent package-lock.json.
        d2nPatchPhase = ''
          # delete package-lock.json as it can lead to conflicts
          rm -f package-lock.json

          # repair 'link:' -> 'file:'
          sed -i 's!link:!file\:!g' $nodeModules/$packageName/package.json

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

          # configure typescript to resolve symlinks locally
          # TODO is this really needed? Node doens't use it
          if [ -f ./tsconfig.json ]; then
            node ${./tsconfig-to-json.js}
          fi
        '';

        # - links dependencies into the node_modules directory + adds bin to PATH
        # - sets HOME=$TMPDIR, as this is required by some npm scripts
        configurePhase = ''
          runHook preConfigure

          ${
            if prodModules != null
            then ''
              ln -s ${prodModules} $sourceRoot/node_modules
              export PATH="$PATH:$sourceRoot/node_modules/.bin"
            ''
            else ""
          }

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
      pkg
      // {sourceInfo = getSourceSpec name version;};
  in
    outputs;
}
