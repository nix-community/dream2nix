{
  dreamLock,
  getSourceSpec,
  getSource,
  getRoot,
  sourceRoot,
  subsystemAttrs,
  packages,
  lib,
  toTOML,
  writeText,
  ...
}: let
  l = lib // builtins;
  isInPackages = name: version: (packages.${name} or null) == version;
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
    echo "dream2nix: replacing relative dependency paths with absolute paths in Cargo.toml"
    substituteInPlace ./Cargo.toml \
      ${replace}
  '';

  # Backup original Cargo.lock if it exists and write our own one
  writeCargoLock = ''
    echo "dream2nix: replacing Cargo.lock with ${cargoLock}"
    mv -f Cargo.lock Cargo.lock.orig || echo "dream2nix: no Cargo.lock was found beforehand"
    cat ${cargoLock} > Cargo.lock
  '';

  # The Cargo.lock for this dreamLock.
  cargoLock = let
    mkPkgEntry = {
      name,
      version,
      ...
    } @ args: let
      # constructs source string for dependency
      makeSource = sourceSpec: let
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
      # constructs source string for dependency entry
      makeDepSource = sourceSpec:
        if sourceSpec.type == "crates-io"
        then makeSource sourceSpec
        else if sourceSpec.type == "git"
        then l.concatStringsSep "#" (l.init (l.splitString "#" (makeSource sourceSpec)))
        else null;
      # removes source type information from the version
      normalizeVersion = version: srcType: l.removeSuffix ("$" + srcType) version;

      sourceSpec = getSourceSpec name version;

      normalizedVersion = normalizeVersion version sourceSpec.type;

      source = let
        src = makeSource sourceSpec;
      in
        if src == null
        then throw "source type '${sourceSpec.type}' not supported"
        else src;
      dependencies =
        l.map
        (
          dep: let
            depSourceSpec = getSourceSpec dep.name dep.version;
            depSource = makeDepSource depSourceSpec;

            normalizedDepVersion = normalizeVersion dep.version depSourceSpec.type;

            hasMultipleVersions =
              l.length (l.attrValues dreamLock.sources.${dep.name}) > 1;
            hasDuplicateVersions = dep.version != normalizedDepVersion;

            # only put version if there are different versions of the dep
            versionString =
              l.optionalString hasMultipleVersions " ${normalizedDepVersion}";
            # only put source if there are duplicate versions of the dep
            # cargo vendor does not support this anyway and so builds will fail
            # until https://github.com/rust-lang/cargo/issues/10310 is resolved.
            srcString =
              l.optionalString hasDuplicateVersions " (${depSource})";
          in "${dep.name}${versionString}${srcString}"
        )
        args.dependencies;

      isMainPackage = isInPackages name version;
    in
      {
        name = sourceSpec.pname or name;
        version = sourceSpec.version or normalizedVersion;
      }
      # put dependencies like how cargo expects them
      // (
        l.optionalAttrs
        (l.length dependencies > 0)
        {inherit dependencies;}
      )
      // (
        l.optionalAttrs
        (sourceSpec.type != "path" && !isMainPackage)
        {inherit source;}
      )
      // (
        l.optionalAttrs
        (sourceSpec.type == "crates-io" && !isMainPackage)
        {checksum = sourceSpec.hash;}
      );
    _package = l.flatten (
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
    package =
      (
        # add packages as dependencies because Cargo expects them to be there aswell
        l.filter
        (pkg: ! l.any (opkg: pkg.name == opkg.name && pkg.version == opkg.version) _package)
        (
          l.mapAttrsToList
          (pname: version: {
            name = pname;
            inherit version;
          })
          dreamLock._generic.packages
        )
      )
      ++ _package;
    lockTOML = toTOML {
      # the lockfile we generate is of version 3
      version = 3;
      inherit package;
    };
  in
    writeText "Cargo.lock" lockTOML;
}
