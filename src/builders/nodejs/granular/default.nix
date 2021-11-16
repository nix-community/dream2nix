{
  jq,
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
  # Funcs

  # AttrSet -> Bool) -> AttrSet -> [x]
  getCyclicDependencies,        # name: version: -> [ {name=; version=; } ]
  getDependencies,              # name: version: -> [ {name=; version=; } ]
  getSource,                    # name: version: -> store-path
  buildPackageWithOtherBuilder, # { builder, name, version }: -> drv

  # Attributes
  subsystemAttrs,       # attrset
  mainPackageName,      # string
  mainPackageVersion,   # string

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
  ...
}@args:

let

  b = builtins;

  nodejsVersion = subsystemAttrs.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  nodeSources = runCommand "node-sources" {} ''
    tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
    mv node-* $out
  '';

  defaultPackage = packages."${mainPackageName}"."${mainPackageVersion}";

  packages =
    lib.mapAttrs
      (name: versions:
        lib.genAttrs
          versions
          (version:
              makePackage name version))
      packageVersions;

  outputs = {
    inherit defaultPackage packages;
  };

  # Generates a derivation for a specific package name + version
  makePackage = name: version:
    let

      deps = getDependencies name version;

      nodeDeps =
        lib.forEach
          deps
          (dep: packages."${dep.name}"."${dep.version}" );

      dependenciesJson = b.toJSON 
        (lib.listToAttrs
          (b.map
            (dep: lib.nameValuePair dep.name dep.version)
            deps));

      pkg =
        produceDerivation name (stdenv.mkDerivation rec {

          packageName = name;
        
          pname = utils.sanitizeDerivationName name;

          # only run build on the main package
          runBuild =
            packageName == mainPackageName
                && version == mainPackageVersion;

          inherit dependenciesJson nodeDeps nodeSources version;

          src = getSource name version;

          buildInputs = [ jq nodejs nodejs.python ];

          # prevents running into ulimits
          passAsFile = [ "dependenciesJson" "nodeDeps" ];

          preConfigurePhases = [ "d2nPatchPhase" ];

          # can be overridden to define alternative install command
          # (defaults to 'npm run postinstall')
          buildScript = null;

          # python script to modify some metadata to support installation
          # (see comments below on d2nPatchPhase)
          fixPackage = "${./fix-package.py}";

          # costs performance and doesn't seem beneficial in most scenarios
          dontStrip = true;

          # TODO: upstream fix to nixpkgs
          # example which requires this:
          #   https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
          unpackCmd =
            if lib.hasSuffix ".tgz" src then
              "tar --delay-directory-restore -xf $src"
            else
              null;

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
          '';

          # - links all direct node dependencies into the node_modules directory
          # - adds executables of direct node module dependencies to PATH
          # - adds the current node module to NODE_PATH
          # - sets HOME=$TMPDIR, as this is required by some npm scripts
          # TODO: don't install dev dependencies. Load into NODE_PATH instead
          # TODO: move all linking to python script, as `ln` calls perform badly
          configurePhase = ''
            runHook preConfigure

            # symlink dependency packages into node_modules
            for dep in $(cat $nodeDepsPath); do
              # add bin to PATH
              if [ -d "$dep/bin" ]; then
                export PATH="$PATH:$dep/bin"
              fi

              if [ -e $dep/lib/node_modules ]; then
                for module in $(ls $dep/lib/node_modules); do
                  if [[ $module == @* ]]; then
                    for submodule in $(ls $dep/lib/node_modules/$module); do
                      mkdir -p $nodeModules/$packageName/node_modules/$module
                      echo "installing: $module/$submodule"
                      ln -s $dep/lib/node_modules/$module/$submodule $nodeModules/$packageName/node_modules/$module/$submodule
                    done
                  else
                    mkdir -p $nodeModules/$packageName/node_modules/
                    echo "installing: $module"
                    ln -s $dep/lib/node_modules/$module $nodeModules/$packageName/node_modules/$module
                  fi
                done
              fi
            done

            # symlink sub dependencies as well as this imitates npm better
            python ${./symlink-deps.py}

            # add dependencies to NODE_PATH
            export NODE_PATH="$NODE_PATH:$nodeModules/$packageName/node_modules"

            export HOME=$TMPDIR

            runHook postConfigure
          '';

          # Runs the install command which defaults to 'npm run postinstall'.
          # Allows using custom install command by overriding 'buildScript'.
          buildPhase = ''
            runHook preBuild

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
            elif [ "$(jq '.scripts.postinstall' ./package.json)" != "null" ]; then
              npm --production --offline --nodedir=$nodeSources run postinstall
            fi

            runHook postBuild
          '';

          # Symlinks executables and manual pages to correct directories
          installPhase = ''
            
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
          '';
        });
    in
      pkg;

in
outputs

