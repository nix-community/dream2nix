{
  lib,
  pkgs,
  runCommand,
  stdenv,
  writeText,

  # dream2nix inputs
  builders,
  externals,
  node2nix ? externals.node2nix,
  utils,
  ...
}:

{
  fetchedSources,
  dreamLock,
  packageOverrides ? {},

  # custom opts:
  standalonePackageNames ? [],
}@args:

let

  b = builtins;

  dreamLock = utils.readDreamLock { inherit (args) dreamLock; };

  inherit (dreamLock.generic) mainPackageName mainPackageVersion;

  dependencyGraph = dreamLock.generic.dependencyGraph;

  standAlonePackages =
    let
      standaloneNames = standalonePackageNames ++ (lib.attrNames dreamLock.generic.dependenciesRemoved);
      standaloneKeys =
        lib.filter
          (key: lib.any (sName: lib.hasPrefix sName key) standaloneNames)
          (lib.attrNames dependencyGraph);
    in
      lib.genAttrs standaloneKeys
        (key:
          (builders.nodejs.node2nix (args // {
            dreamLock =
              let
                nameVer = lib.splitString "#" key;
                name = b.elemAt nameVer 0;
                version = b.elemAt nameVer 1;
              in
                lib.recursiveUpdate dreamLock 
                  {
                    generic.mainPackagenName = name;
                    generic.mainPackagenVersion = version;

                    # re-introduce removed dependencies
                    generic.dependencyGraph."${key}" =
                      # b.trace "re-introduce removed ${b.toString dreamLock.generic.dependenciesRemoved."${key}" or []}"
                      dreamLock.generic.dependencyGraph."${key}"
                      ++ dreamLock.generic.dependenciesRemoved."${key}" or [];
                  };
          })).package
        );

  mainPackageKey =
    "${mainPackageName}#${mainPackageVersion}";

  nodejsVersion = dreamLock.buildSystem.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  nodeSources = runCommand "node-sources" {} ''
    tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
    mv node-* $out
  '';

  allPackages =
    lib.genAttrs
      (lib.attrNames fetchedSources)
      (key:
        let
          split = lib.splitString "#" key;
          name = b.elemAt split 0;
          version = b.elemAt split 1;
        in
          makePackage name version);

  makePackage = name: version:
    let
      pkgKey = "${name}#${version}";
      pkg =
        (stdenv.mkDerivation rec {

          packageName = name;
        
          pname = utils.sanitizeDerivationName name;

          inherit version;

          src = fetchedSources."${pkgKey}";

          buildInputs = [ nodejs nodejs.python ];

          ignoreScripts = false;

          inherit nodeSources;

          dependencies_json = writeText "dependencies.json" 
            (b.toJSON 
              (lib.listToAttrs
                (b.map
                  (pKey:
                    let
                      split = lib.splitString "#" pKey;
                      pname = b.elemAt split 0;
                      version = b.elemAt split 1;
                    in
                      lib.nameValuePair pname version)
                  dreamLock.generic.dependencyGraph."${pkgKey}" or [])));

          nodeDeps =
            lib.forEach
              (dependencyGraph."${pkgKey}" or [])
              (depKey:
                allPackages."${depKey}"
              )
            ++
            lib.forEach (dreamLock.generic.dependenciesRemoved."${pkgKey}" or [])
              (removedDep: standAlonePackages."${pkgKey}");

          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            nodeModules=$out/lib/node_modules

            mkdir -p $nodeModules

            cd $TMPDIR

            unpackFile ${src}

            # Make the base dir in which the target dependency resides first
            mkdir -p "$(dirname "$nodeModules/${packageName}")"

            # install source
            if [ -f "${src}" ]
            then
                # Figure out what directory has been unpacked
                packageDir="$(find . -maxdepth 1 -type d | tail -1)"

                # Restore write permissions
                find "$packageDir" -type d -exec chmod u+x {} \;
                chmod -R u+w "$packageDir"

                # Move the extracted tarball into the output folder
                mv "$packageDir" "$nodeModules/${packageName}"
            elif [ -d "${src}" ]
            then
                strippedName="$(stripHash ${src})"

                # Restore write permissions
                chmod -R u+w "$strippedName"

                # Move the extracted directory into the output folder
                mv "$strippedName" "$nodeModules/${packageName}"
            fi

            # repair 'link:' -> 'file:'
            mv $nodeModules/${packageName}/package.json $nodeModules/${packageName}/package.json.old
            cat $nodeModules/${packageName}/package.json.old | sed 's!link:!file\:!g' > $nodeModules/${packageName}/package.json
            rm $nodeModules/${packageName}/package.json.old

            # symlink dependency packages into node_modules
            for dep in $nodeDeps; do
              if [ -e $dep/lib/node_modules ]; then
                for module in $(ls $dep/lib/node_modules); do
                  if [[ $module == @* ]]; then
                    for submodule in $(ls $dep/lib/node_modules/$module); do
                      mkdir -p $nodeModules/${packageName}/node_modules/$module
                      echo "ln -s $dep/lib/node_modules/$module/$submodule $nodeModules/${packageName}/node_modules/$module/$submodule"
                      ln -s $dep/lib/node_modules/$module/$submodule $nodeModules/${packageName}/node_modules/$module/$submodule
                    done
                  else
                    mkdir -p $nodeModules/${packageName}/node_modules/
                    echo "ln -s $dep/lib/node_modules/$module $nodeModules/${packageName}/node_modules/$module"
                    ln -s $dep/lib/node_modules/$module $nodeModules/${packageName}/node_modules/$module
                  fi
                done
              fi
            done

            cd "$nodeModules/${packageName}"

            # fix package.json malformed dependency versions
            python ${./fix-package-lock.py} $dependencies_json package.json

            export HOME=$TMPDIR

            flags=("--offline" "--production" "--nodedir=$nodeSources")
            if [ -n "$ignoreScripts" ]; then
              flags+=("--ignore-scripts")
            fi

            npm "''${flags[@]}" install

            # Create symlink to the deployed executable folder, if applicable
              if [ -d "$nodeModules/.bin" ]
              then
                ln -s $nodeModules/.bin $out/bin
              fi

              # Create symlinks to the deployed manual page folders, if applicable
              if [ -d "$nodeModules/${packageName}/man" ]
              then
                  mkdir -p $out/share
                  for dir in "$nodeModules/${packageName}/man/"*
                  do
                      mkdir -p $out/share/man/$(basename "$dir")
                      for page in "$dir"/*
                      do
                          ln -s $page $out/share/man/$(basename "$dir")
                      done
                  done
              fi

            runHook postInstall
          '';
        });
    in
      standAlonePackages."${name}#${version}"
      or
      (utils.applyOverridesToPackage packageOverrides pkg name);

  package = makePackage mainPackageName mainPackageVersion;

in
{

  inherit package allPackages;
    
}
