{
  dreamLock,
  getSourceSpec,
  getSource,
  getRoot,
  sourceRoot,
  subsystemAttrs,
  packages,
  lib,
  dlib,
  utils,
  pkgs,
  ...
}: let
  l = lib // builtins;
  isInPackages = name: version: (packages.${name} or null) == version;
  # a make overridable for rust derivations specifically
  makeOverridable = f: origArgs: let
    result = f origArgs;

    # Creates a functor with the same arguments as f
    copyArgs = g: l.setFunctionArgs g (l.functionArgs f);
    # Changes the original arguments with (potentially a function that returns) a set of new attributes
    overrideWith = newArgs:
      origArgs
      // (
        if l.isFunction newArgs
        then newArgs origArgs
        else newArgs
      );

    # Re-call the function but with different arguments
    overrideArgs = copyArgs (newArgs: makeOverridable f (overrideWith newArgs));
    # Change the result of the function call by applying g to it
    overrideResult = g: makeOverridable (copyArgs (args: g (f args))) origArgs;
  in
    result.derivation
    // {
      override = args:
        overrideArgs {
          args =
            origArgs.args
            // (
              if l.isFunction args
              then args origArgs.args
              else args
            );
        };
      overrideRustToolchain = f: overrideArgs {toolchain = f origArgs.toolchain;};
      overrideAttrs = fdrv: overrideResult (x: {derivation = x.derivation.overrideAttrs fdrv;});
    };
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
    buildWithToolchain = args:
      makeOverridable
      (args: {
        derivation =
          (mkBuildFunc args.toolchain)
          (
            args.args
            // {
              passthru =
                (args.args.passthru or {})
                // {rustToolchain = args.toolchain;};
            }
          );
      })
      args;
  in
    buildWithToolchain;

  # Backup original Cargo.lock if it exists and write our own one
  writeCargoLock = ''
    mv -f Cargo.lock Cargo.lock.orig || echo "no Cargo.lock"
    cat ${cargoLock} > Cargo.lock
  '';

  # The Cargo.lock for this dreamLock.
  cargoLock = let
    mkPkgEntry = {
      name,
      version,
      ...
    } @ args: let
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
      makeDepSource = sourceSpec:
        if sourceSpec.type == "crates-io"
        then makeSource sourceSpec
        else if sourceSpec.type == "git"
        then l.concatStringsSep "#" (l.init (l.splitString "#" (makeSource sourceSpec)))
        else null;
      sourceSpec = getSourceSpec name version;
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
            hasMultipleVersions =
              l.length (l.attrValues dreamLock.sources.${dep.name}) > 1;
            hasDuplicateVersions =
              l.hasSuffix ("$" + depSourceSpec.type) dep.version;
            # only put version if there are different versions of the dep
            versionString =
              l.optionalString hasMultipleVersions " ${depSourceSpec.version}";
            # only put source if there are duplicate versions of the dep
            # cargo vendor does not support this anyway and so builds will fail
            # until https://github.com/rust-lang/cargo/issues/10310 is resolved.
            srcString =
              l.optionalString hasDuplicateVersions " (${depSource})";
          in "${depSourceSpec.pname}${versionString}${srcString}"
        )
        args.dependencies;
      isMainPackage = isInPackages name version;
    in
      {
        name = sourceSpec.pname;
        version = sourceSpec.version;
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
