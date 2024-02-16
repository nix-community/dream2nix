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
  nodejsUtils = import ../../../lib/internal/nodejsUtils.nix {
    inherit lib;
    parseSpdxId = _: _;
  };
  graphUtils = import ../../../lib/internal/graphUtils.nix {inherit lib;};
  utils = import ./utils.nix {inherit lib;};

  isLink = plent: plent ? link && plent.link;

  pdefs = parse cfg.packageLock;

  parseSource = plent: name:
    l.warnIfNot (plent ? resolved) "Package ${name}/${plent.version} didn't provide 'resolved' where the package can be fetched from."
    (
      if isLink plent
      then
        # entry is local file
        (builtins.dirOf cfg.packageLockFile) + "/${plent.resolved}"
      else if nodejsUtils.identifyGitUrl plent.resolved
      then
        # entry is a git dependency
        builtins.fetchGit
        (nodejsUtils.parseGitUrl plent.resolved)
        // {
          shallow = true;
        }
      else
        # entry is a regular tarball / archive
        # which usually comes from the npmjs registry
        l.warnIfNot (plent ? integrity) "Package ${name}/${plent.version} didn't provide 'integrity' field, which is required for url dependencies."
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
        }
    );
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

    rootPackage = let
      ## ----------- Metainformations ----------
      fileSystem = graphUtils.getFileSystem pdefs (utils.getSanitizedGraph {
        inherit plent pdefs;
      });
      fileSystemProd = graphUtils.getFileSystem pdefs (utils.getSanitizedGraph {
        inherit pdefs plent;
        filterTree = {
          dev = false;
        };
      });

      rinfo = info // {inherit fileSystem;};
      name = plent.name or lock.name;

      self = config.groups.all.packages.${name}.${plent.version}.evaluated;

      bins = getBins path plent;

      ## ----------- Output derviations ----------

      prepared-dev = {
        imports = [
          ./modules/prepared-dev.nix
        ];
        _module.args = {
          packageName = name;
          inherit plent fileSystem;
          inherit (config.deps) nodejs;
        };
      };

      dist = {
        imports = [
          ./modules/dist.nix
        ];
        _module.args = {
          packageName = name;
          inherit plent;
          inherit (cfg) packageLockFile trustedDeps;
          inherit (self) prepared-dev;
          inherit (config.deps) nodejs jq;
        };
      };

      prepared-prod = {
        imports = [
          ./modules/prepared-prod.nix
        ];
        _module.args = {
          packageName = name;
          fileSystem = fileSystemProd;
          inherit plent;
          inherit (config.deps) nodejs;
        };
      };

      installed = {
        imports = [
          ./modules/installed.nix
        ];
        _module.args = {
          packageName = name;
          inherit bins plent;
          inherit (self) dist prepared-prod;
          inherit (config.deps) nodejs jq;
        };
      };
    in {
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
              # other derivations
              inherit (self) installed prepared-dev prepared-prod;
            };
        };
      };
    };

    ## --------- leaf package ------------
    leafPackage = let
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
  in
    if path == ""
    then rootPackage
    else leafPackage;
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

  public = l.mkForce (
    (config.groups.all.packages.${config.name}.${config.version}.public)
    // {
      inherit config;
    }
  );

  # OUTPUTS
  WIP-nodejs-builder-v3 = {
    inherit pdefs;
    packageLock =
      lib.mkDefault
      (builtins.fromJSON (builtins.readFile cfg.packageLockFile));
  };
}
