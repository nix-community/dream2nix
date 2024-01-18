{
  config,
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  cfg = config.WIP-nodejs-builder-v3;

  # debugMsg = msg: val: builtins.trace "${msg} ${(builtins.toJSON "")}" val;

  inherit (config.deps) fetchurl;

  nodejsLockUtils = import ../../../lib/internal/nodejsLockUtils.nix {inherit lib;};
  graphUtils = import ../../../lib/internal/graphUtils.nix {inherit lib;};
  utils = import ./utils.nix {inherit lib;};

  isLink = plent: plent ? link && plent.link;

  pdefs = parse cfg.packageLock;

  parseSource = plent: name:
    if isLink plent
    then
      # entry is local file
      (builtins.dirOf cfg.packageLockFile) + "/${plent.resolved}"
    else
      config.deps.mkDerivation {
        inherit name;
        inherit (plent) version;
        src = fetchurl {
          url = plent.resolved;
          hash = plent.integrity;
        };
        dontBuild = true;
        unpackPhase = ''
          runHook preUnpack
          unpackFallback(){
            local fn="$1"
            tar xf "$fn"
          }
          unpackCmdHooks+=(unpackFallback)
          unpackFile $src
          chmod -R +X .
          runHook postUnpack
        '';
        installPhase = ''
          if [ -f "$src" ]
          then
            # Figure out what directory has been unpacked
            packageDir="$(find . -maxdepth 1 -type d | tail -1)"
            echo "packageDir $packageDir"
            # Restore write permissions
            find "$packageDir" -type d -exec chmod u+x {} \;
            chmod -R u+w -- "$packageDir"
            # Move the extracted tarball into the output folder
            mv -- "$packageDir" $out
          elif [ -d "$src" ]
          then
            strippedName="$(stripHash $src)"
            echo "strippedName $strippedName"
            # Restore write permissions
            chmod -R u+w -- "$strippedName"
            # Move the extracted directory into the output folder
            mv -- "$strippedName" $out
          fi
        '';
      };
  # Lock -> Pdefs
  parse = lock:
    builtins.foldl'
    (acc: entry:
      acc
      // {
        # Merge package paths
        # { "5.3.0" = <CODE>; }
        ${entry.name} =
          acc.${entry.name}
          or {}
          // builtins.mapAttrs (
            version: pkg:
              pkg
              // {
                info =
                  pkg.info
                  // {
                    allPaths =
                      acc.${entry.name}.${version}.info.allPaths
                      or {}
                      // {${pkg.info.initialPath} = true;};
                  };
              }
          ) (entry.value);
      })
    {}
    # [{name=; value=;} ...]
    (l.mapAttrsToList (parseEntry lock) lock.packages);

  ############################################################
  # pdefs = parse cfg.packageLock;
  # {name}.{version}.{...}
  groups.all.packages =
    lib.mapAttrs
    (
      name: versions:
        lib.mapAttrs
        (version: entry: {module = entry;})
        versions
    )
    pdefs;

  ############################################################
  # Utility functions #

  # Type: lock.packages -> Bins
  getBins = path: plent:
    if plent ? bin
    then
      if l.isAttrs plent.bin
      then plent.bin
      else if l.isList plent.bin
      then {} l.foldl' (res: bin: res // {${bin} = bin;}) {} plent.bin
      else throw ""
    else {};

  # Collect all dependencies of a package.
  getDependencies = lock: path: plent:
    l.mapAttrs (name: _descriptor: {
      dev = plent.dev or false;
      version = let
        # Need this util as dependencies no explizitly locked version
        # This findEntry is needed to find the exact locked version
        packageIdent = nodejsLockUtils.findEntry lock path name;
      in
        # Read version from package-lock entry for the resolved package
        lock.packages.${packageIdent}.version;
    })
    (plent.dependencies or {} // plent.devDependencies or {} // plent.optionalDependencies or {});

  # Takes one entry of "package" from package-lock.json
  # lock :: Whole lockfile.
  # path :: Key of the package e.g. "/node_modules/prettier". Could also be nested
  # plent :: The lock entry. Includes meta information about the package.
  parseEntry = lock: path: plent: let
    info = utils.getInfo path plent;
    makeNodeModules = ./build-node-modules.mjs;
    installTrusted = ./install-trusted-modules.mjs;
  in
    if path == ""
    then let
      rinfo = info // {inherit fileSystem;};
      name = plent.name or lock.name;

      fileSystem = graphUtils.getFileSystem pdefs (info.pdefs' {
        graph = pdefs;
        root = {
          inherit name;
          inherit (plent) version;
        };
      });
      fileSystemProd = graphUtils.getFileSystem pdefs (info.pdefs' {
        graph = pdefs;
        root = {
          inherit name;
          inherit (plent) version;
        };
        opt = {
          dev = false;
        };
      });

      self = config.groups.all.packages.${name}.${plent.version}.evaluated;

      prepared-dev = let
        module = {
          imports = [
            # config.groups.all.packages.${name}.${plent.version}
            dream2nix.modules.dream2nix.mkDerivation
          ];
          config = {
            inherit (plent) version;
            name = name + "-node_modules-dev";
            env = {
              FILESYSTEM = builtins.toJSON fileSystem;
            };

            mkDerivation = {
              dontUnpack = true;
              buildInputs = with config.deps; [nodejs];
              buildPhase = ''
                node ${makeNodeModules}
              '';
            };
          };
        };
      in
        module;

      prepared-prod = let
        module = {
          imports = [
            dream2nix.modules.dream2nix.mkDerivation
          ];
          config = {
            inherit (plent) version;
            name = name + "-node_modules-prod";
            env = {
              FILESYSTEM = builtins.toJSON fileSystemProd;
            };
            mkDerivation = {
              dontUnpack = true;
              buildInputs = with config.deps; [nodejs];
              buildPhase = ''
                node ${makeNodeModules}
              '';
            };
          };
        };
      in
        module;

      bins = getBins path plent;

      installed = config.deps.mkDerivation {
        inherit (plent) version;
        name = name + "-installed";
        nativeBuildInputs = with config.deps; [jq];
        buildInputs = with config.deps; [nodejs];
        src = self.dist;
        env = {
          BINS = builtins.toJSON bins;
        };
        configurePhase = ''
          cp -r ${self.prepared-prod}/node_modules node_modules
        '';
        installPhase = ''
          mkdir -p $out/lib/node_modules/${name}
          cp -r . $out/lib/node_modules/${name}

          mkdir -p $out/bin
          echo $BINS | jq 'to_entries | map("ln -s $out/lib/node_modules/${name}/\(.value) $out/bin/\(.key); ") | .[]' -r | bash
        '';
      };
      dist = {
        imports = [
          dream2nix.modules.dream2nix.mkDerivation
        ];
        config = {
          inherit (plent) version;
          name = name + "-dist";
          env = {
            TRUSTED = builtins.toJSON cfg.trustedDeps;
          };
          mkDerivation = {
            # inherit (entry) version;
            src = builtins.dirOf cfg.packageLockFile;
            buildInputs = with config.deps; [nodejs jq];
            configurePhase = ''
              cp -r ${self.prepared-dev}/node_modules node_modules
              chmod -R +w node_modules
              node ${installTrusted}
            '';
            buildPhase = ''
              echo "BUILDING... $name"

              if [ "$(jq -e '.scripts.build' ./package.json)" != "null" ]; then
                echo "BUILDING... $name"
                export HOME=.virt
                npm run build
              else
                echo "$(jq -e '.scripts.build' ./package.json)"
                echo "No build script";
              fi;
            '';
            installPhase = ''
              # TODO: filter files
              rm -rf node_modules
              cp -r . $out
            '';
          };
        };
      };
    in {
      # Root level package
      name = name;
      value = {
        ${plent.version} = {
          dependencies = getDependencies lock path plent;
          dev = plent.dev or false;
          info = rinfo;
          inherit bins prepared-dev dist prepared-prod installed;
          # -- self = groups.all.packages.name.version.evaluated
          public =
            self.dist
            // {
              inherit installed;
            };
        };
      };
    }
    # End Root level package
    else let
      name = l.last (builtins.split "node_modules/" path);
      source = parseSource plent name;
      bins = getBins path plent;
      version =
        if isLink plent
        then let
          pjs = l.fromJSON (l.readFile (source + "/package.json"));
        in
          pjs.version
        else plent.version;
    in
      # Every other package
      {
        inherit name;
        value = {
          ${version} = {
            inherit info bins;

            dev = plent.dev or false;

            dependencies = getDependencies lock path plent;
            # We need to determine the initial state of every package and
            # TODO: define dist and installed if they are in source form. We currently only do this for the root package.
            "dist" = source;
            public = source;
          };
        };
      };
in {
  inherit groups;

  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.WIP-groups
  ];

  overrideAll =
    {
      imports = [
        dream2nix.modules.dream2nix.core
      ];
    }
    // (import ./types.nix {
      inherit
        lib
        dream2nix
        specialArgs
        ;
    })
    .pdefEntryOptions;

  # declare external dependencies
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchurl
      jq
      tree
      ;
    nodejs = nixpkgs.nodejs_latest;
    inherit
      (nixpkgs.stdenv)
      mkDerivation
      ;
  };

  public = l.mkForce (config.groups.all.packages.${config.name}.${config.version}.public);

  # OUTPUTS
  WIP-nodejs-builder-v3 = {
    inherit pdefs;
    packageLock =
      lib.mkDefault
      (builtins.fromJSON (builtins.readFile cfg.packageLockFile));
  };
}
