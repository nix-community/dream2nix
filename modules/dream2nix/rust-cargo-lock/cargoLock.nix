{
  lib,
  dreamLock,
  # nixpkgs
  writeText,
}:
# The Cargo.lock for this dreamLock.
let
  l = lib // builtins;

  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};

  dreamLockLoaded = readDreamLock {inherit dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  inherit
    (dreamLockInterface)
    getSourceSpec
    subsystemAttrs
    packages
    ;

  toTOML = import ../../../lib/internal/toTOML.nix {inherit lib;};

  isInPackages = name: version: (packages.${name} or null) == version;
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
  writeText "Cargo.lock" lockTOML
