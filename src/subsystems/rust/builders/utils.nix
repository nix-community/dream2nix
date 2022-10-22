{
  getSourceSpec,
  getSource,
  getRoot,
  sourceRoot,
  dreamLock,
  lib,
  dlib,
  utils,
  subsystemAttrs,
  pkgs,
  ...
}: let
  l = lib // builtins;
in rec {
  getMeta = pname: version: let
    meta = subsystemAttrs.meta.${pname}.${version};
  in
    meta
    // {
      license = l.map (name: l.licenses.${name}) meta.license;
    };

  # Gets the root source for a package
  getRootSource = pname: version: let
    root = getRoot pname version;
  in
    getSource root.pname root.version;

  # Generates a script that replaces relative path dependency paths with absolute
  # ones, if the path dependency isn't in the source dream2nix provides
  replaceRelativePathsWithAbsolute = replacements: let
    replace =
      l.concatStringsSep
      " \\\n"
      (
        l.mapAttrsToList
        (
          # TODO: this is not great, because it forces us to include the entire
          # sourceRoot here, which could possibly cause more rebuilds than necessary
          # when source is changed (although this mostly depends on how the project
          # repository is structured). doing this properly is pretty complex, but
          # it should still be done later.
          from: relPath: ''--replace "\"${from}\"" "\"${sourceRoot}/${relPath}\""''
        )
        replacements
      );
  in ''
    substituteInPlace ./Cargo.toml \
      ${replace}
  '';

  mkBuildWithToolchain = mkBuildFunc: let
    buildWithToolchain = toolchain: args: let
      # we pass the actual overrideAttrs function through another attribute
      # so we can apply it to the actual derivation later
      overrideDrvFunc = args.overrideDrvFunc or (_: {});
      cleanedArgs = l.removeAttrs args ["overrideDrvFunc"];
      _drv = ((mkBuildFunc toolchain) cleanedArgs).overrideAttrs overrideDrvFunc;
      drv =
        _drv
        // {
          passthru = (_drv.passthru or {}) // {rustToolchain = toolchain;};
        };
    in
      drv
      // {
        overrideRustToolchain = f: let
          newToolchain = toolchain // (f toolchain);
          # we need to do this since dream2nix overrides
          # use the passthru to get attr names
          maybePassthru =
            l.optionalAttrs
            (newToolchain ? passthru)
            {inherit (newToolchain) passthru;};
        in
          buildWithToolchain newToolchain (args // maybePassthru);
        overrideAttrs = f:
          buildWithToolchain toolchain (
            args
            // {
              # we need to apply the old overrideDrvFunc as well here
              # so that other potential overrideAttr usages aren't lost
              # (otherwise only one of them would be applied)
              overrideDrvFunc = prev:
                ((args.overrideDrvFunc or (_: {})) prev) // (f prev);
            }
          );
      };
  in
    buildWithToolchain;

  # Script to write the Cargo.lock if it doesn't already exist.
  writeCargoLock = ''
    rm -f "$PWD/Cargo.lock"
    cat ${cargoLock} > "$PWD/Cargo.lock"
  '';

  # The Cargo.lock for this dreamLock.
  cargoLock = let
    mkPkgEntry = {
      name,
      version,
      dependencies,
    }: let
      getSource = name: version: let
        sourceSpec = getSourceSpec name version;
        source =
          if sourceSpec.type == "crates-io"
          then "registry+https://github.com/rust-lang/crates.io-index"
          else if sourceSpec.type == "git"
          then let
            gitSpec =
              l.findFirst
              (src: src.url == sourceSpec.url && src.sha == sourceSpec.rev)
              (throw "no git source: ${sourceSpec.url}#${sourceSpec.rev}")
              (subsystemAttrs.gitSources or {});
            refPart =
              l.optionalString
              (gitSpec ? type)
              "?${gitSpec.type}=${gitSpec.value}";
          in "git+${sourceSpec.url}${refPart}#${sourceSpec.rev}"
          else null;
      in
        source;
      # TODO: this is currently unused but will be used in the future, see
      # comment down below in dependencies.
      getDepSource = name: version: let
        sourceSpec = getSourceSpec name version;
      in
        if sourceSpec.type == "crates-io"
        then null
        else if sourceSpec.type == "git"
        then l.head (l.splitString "#" (getSource name version))
        else null;
      sourceSpec = getSourceSpec name version;
      source = let
        src = getSource name version;
      in
        if src == null
        then throw "source type '${sourceSpec.type}' not supported"
        else src;
    in
      {
        inherit name version;
        # put dependencies like how cargo expects them
        dependencies =
          l.map
          (
            dep: let
              # only put version if there are different versions of the dep
              hasMultipleVersions =
                (l.length (l.attrValues dreamLock.sources.${dep.name})) > 1;
              versionString =
                l.optionalString hasMultipleVersions " ${dep.version}";
              # TODO: we need to comment out this and put the srcString only
              # if there are duplicate versions of a dependency. This currently
              # doesn't matter for us since the two Rust builders we have
              # (brp and crane) use cargo, and cargo vendor does not support
              # duplicate dependency versions. However if we get a more granular
              # builder that does not use cargo, we would be able to test and
              # support this, since we wouldn't be limited to cargo's functionality.
              # src = getDepSource dep.name dep.version;
              src = null;
              srcString = l.optionalString (src != null) " (${src})";
            in "${dep.name}${versionString}${srcString}"
          )
          dependencies;
      }
      // (
        l.optionalAttrs
        (sourceSpec.type != "path")
        {inherit source;}
      )
      // (
        l.optionalAttrs
        (sourceSpec.type == "crates-io")
        {checksum = sourceSpec.hash;}
      );
    package = l.flatten (
      l.mapAttrsToList
      (
        name: versions:
          l.mapAttrsToList
          (
            version: dependencies:
              mkPkgEntry {inherit name version dependencies;}
          )
          versions
      )
      dreamLock.dependencies
    );
    lockTOML = utils.toTOML {
      # the lockfile we generate is of version 3
      version = 3;
      inherit package;
    };
  in
    pkgs.writeText "Cargo.lock" lockTOML;
}
