{
  simpleTranslate2,
  lib,
  ...
}: let
  l = lib // builtins;
  translate = {
    projectRelPath,
    sources,
    dependencies,
    metadata,
  }:
    simpleTranslate2
    ({objectsByKey, ...}: rec {
      translatorName = "composer-lock-cached";
      location = projectRelPath;
      subsystemName = "php";

      subsystemAttrs = {
        noDev = metadata.noDev or false;
        phpSemver = metadata.phpSemver or "*";
        phpExtensions = metadata.phpExtensions or [];
        composerPluginApiSemver = {};
      };

      defaultPackage = metadata.projectName;

      exportedPackages = {
        "${defaultPackage}" = metadata.projectVersion or "unknown";
      };

      # Build serialized objects from cached data
      serializedRawObjects = l.flatten (
        l.mapAttrsToList (
          name: versions:
            l.mapAttrsToList (version: sourceSpec: {
              inherit name version;
              source = sourceSpec;
              dependencies = dependencies.${name}.${version} or [];
            })
            versions
        )
        sources
      );

      extractors = {
        name = rawObj: finalObj: rawObj.name;
        version = rawObj: finalObj: rawObj.version;
        dependencies = rawObj: finalObj: rawObj.dependencies;
        sourceSpec = rawObj: finalObj:
          if rawObj.source.type == "path"
          then {
            inherit (rawObj.source) type;
            path = rawObj.source.path or ".";
            rootName = finalObj.name;
            rootVersion = finalObj.version;
          }
          else if rawObj.source.type == "git"
          then {
            inherit (rawObj.source) type url rev;
            hash = rawObj.source.hash or null;
            submodules = rawObj.source.submodules or false;
          }
          else if rawObj.source.type == "url"
          then {
            inherit (rawObj.source) type url;
            hash = rawObj.source.hash or null;
          }
          else rawObj.source;
      };

      keys = {};
      extraObjects = [];
    });
in
  translate
