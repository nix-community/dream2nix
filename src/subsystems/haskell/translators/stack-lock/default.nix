{
  dlib,
  lib,
  pkgs,
  utils,
  name,
  inputs,
  ...
}: let
  l = lib // builtins;
in {
  type = "ifd";

  /*
  Automatically generate unit tests for this translator using project sources
  from the specified list.
  */
  generateUnitTestsForProjects = [
    (builtins.fetchTarball {
      url = "https://github.com/NorfairKing/cabal2json/tarball/8b864d93e3e99eb547a0d377da213a1fae644902";
      sha256 = "0zd38mzfxz8jxdlcg3fy6gqq7bwpkfann9w0vd6n8aasyz8xfbpj";
    })
  ];

  discoverProject = tree:
    l.any
    (filename: l.hasSuffix "stack.yaml.lock" filename)
    (l.attrNames tree.files);

  # translate from a given source and a project specification to a dream-lock.
  translate = let
    stackLockUtils = import ./utils.nix {inherit dlib lib pkgs;};
    all-cabal-hashes = let
      all-cabal-hashes' = inputs.all-cabal-json;
      names = dlib.listDirs all-cabal-hashes';
      getVersions = name: dlib.listDirs "${all-cabal-hashes'}/${name}";
    in
      l.genAttrs names
      (name:
        l.genAttrs
        (getVersions name)
        (
          version:
            (l.fromJSON (l.readFile "${all-cabal-hashes'}/${name}/${version}/${name}.hashes.json"))
            .package-hashes
        ));
  in
    {
      project,
      tree,
      ...
    } @ args: let
      # get the root source and project source
      rootSource = tree.fullPath;
      projectSource = "${tree.fullPath}/${project.relPath}";
      projectTree = tree.getNodeFromPath project.relPath;

      # parse the cabal file
      cabalFiles =
        l.filter
        (l.hasSuffix ".cabal")
        (l.attrNames projectTree.files);

      cabalFile = projectTree.getNodeFromPath (l.head cabalFiles);
      cabal = stackLockUtils.fromCabal cabalFile.fullPath project.name;
      defaultPackageVersion =
        l.concatStringsSep
        "."
        (l.map l.toString cabal.description.package.version);

      stackLock =
        stackLockUtils.fromYaml
        (projectTree.getNodeFromPath "stack.yaml.lock").fullPath;

      snapshotEntry = l.head (stackLock.snapshots);

      snapshotYamlFile = builtins.fetchurl {
        url = snapshotEntry.completed.url;
        sha256 = snapshotEntry.completed.sha256;
      };

      snapshot = stackLockUtils.fromYaml snapshotYamlFile;

      compiler = snapshot.resolver.compiler;
      compilerSplit = l.splitString "-" snapshot.resolver.compiler;
      compilerName = l.head compilerSplit;
      compilerVersion = l.last compilerSplit;

      hidden =
        haskellUtils.ghcVersionToHiddenPackages."${compilerVersion}" or haskellUtils.ghcVersionToHiddenPackages."9.0.2";
      # TODO: find out what to do with the hidden packages from the snapshot
      # Currently it looks like those should not be included
      # // (
      #   l.genAttrs
      #   (l.attrNames snapshot.hidden)
      #   (name: null)
      # );

      serializedRawObjects =
        l.map
        parseStackLockEntry
        (stackLock.packages ++ snapshot.packages);

      allCandidates =
        l.map
        (rawObj: dlib.nameVersionPair rawObj.name rawObj.version)
        serializedRawObjects;

      haskellUtils = import ../utils.nix {inherit inputs lib pkgs;};

      cabalData =
        haskellUtils.batchFindJsonFromCabalCandidates
        allCandidates;

      parseStackLockEntry = entry:
        if entry ? completed
        then parseHackageUrl entry.completed.hackage
        else parseHackageUrl entry.hackage;

      parseHackageUrl = url:
      # example:
      # AC-Angle-1.0@sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065,544
      let
        splitAtAt = l.splitString "@" url;
        nameVersion = l.head splitAtAt;
        hashAll = l.last splitAtAt;
        nameVersionPieces = l.splitString "-" nameVersion;
        version = l.last nameVersionPieces;
        name = l.concatStringsSep "-" (l.init nameVersionPieces);
        hashChecksumSplit = l.splitString ":" hashAll;
        hashType = l.head hashChecksumSplit;
        hashAndLength = l.last hashChecksumSplit;
        hashLengthSplit = l.splitString "," hashAndLength;
        hash = l.head hashLengthSplit;
        length = l.last hashLengthSplit;
      in {
        inherit name version hash;
      };
    in
      dlib.simpleTranslate2.translate
      ({objectsByKey, ...}: rec {
        translatorName = name;

        # relative path of the project within the source tree.
        location = project.relPath;

        # the name of the subsystem
        subsystemName = "haskell";

        # Extract subsystem specific attributes.
        # The structure of this should be defined in:
        #   ./src/specifications/{subsystem}
        subsystemAttrs = {
          cabalHashes =
            l.listToAttrs
            (
              l.map
              (
                rawObj:
                  l.nameValuePair
                  "${rawObj.name}#${rawObj.version}"
                  rawObj.hash
              )
              serializedRawObjects
            );
          compiler = {
            name = compilerName;
            version = compilerVersion;
          };
        };

        # name of the default package
        defaultPackage = cabal.description.package.name;

        /*
        List the package candidates which should be exposed to the user.
        Only top-level packages should be listed here.
        Users will not be interested in all individual dependencies.
        */
        exportedPackages = {
          "${defaultPackage}" = defaultPackageVersion;
        };

        /*
        a list of raw package objects
        */
        inherit serializedRawObjects;

        /*
        Define extractor functions which each extract one property from
        a given raw object.
        (Each rawObj comes from serializedRawObjects).

        Extractors can access the fields extracted by other extractors
        by accessing finalObj.
        */
        extractors = {
          name = rawObj: finalObj:
            rawObj.name;

          version = rawObj: finalObj:
            rawObj.version;

          dependencies = rawObj: finalObj:
            l.pipe cabalData
            [
              (haskellUtils.getDependencyNames finalObj)
              (l.filter
                (name:
                  # ensure package is not a hidden package
                    (! hidden ? ${name})
                    # ignore packages which are not part of the snapshot or lock file
                    && (objectsByKey.name ? ${name})))
              (l.map
                (depName: {
                  name = depName;
                  version = objectsByKey.name.${depName}.version;
                }))
            ];

          sourceSpec = rawObj: finalObj:
          # example
          # https://hackage.haskell.org/package/AC-Angle-1.0/AC-Angle-1.0.tar.gz
          {
            type = "http";
            url = haskellUtils.getHackageUrl finalObj;
            hash = "sha256:${all-cabal-hashes.${finalObj.name}.${finalObj.version}.SHA256}";
          };
        };

        /*
        Define extra extractors which will be used to key all
        final objects, so objects can be accessed via:
        `objectsByKey.${keyName}.${value}`
        */
        keys = {
          name = rawObj: finalObj:
            finalObj.name;
        };

        /*
        Add extra objects (list of `finalObj`) to be added to
        the dream-lock.
        */
        extraObjects = [
          {
            name = defaultPackage;
            version = defaultPackageVersion;

            dependencies = let
              testTargetBuildDepends = l.flatten (
                l.mapAttrsToList
                (suiteName: suite:
                  suite.condTreeData.build-info.targetBuildDepends
                  ++ suite.condTreeData.build-info.buildToolDepends)
                cabal.test-suites or {}
              );

              depNames =
                l.map
                (dep: dep.package-name)
                (
                  cabal.library.condTreeData.build-info.targetBuildDepends
                  or []
                  ++ cabal.library.condTreeData.build-info.buildToolDepends or []
                  ++ testTargetBuildDepends
                );
            in
              l.map
              (depName: {
                name = depName;
                version = objectsByKey.name.${depName}.version;
              })
              (l.filter
                (name:
                  (! hidden ? ${name})
                  && (name != defaultPackage))
                depNames);

            sourceSpec = {
              type = "path";
              path = projectTree.fullPath;
            };
          }
        ];
      });

  extraArgs = {};
}
