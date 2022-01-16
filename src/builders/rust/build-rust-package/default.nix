{
  lib,
  pkgs,

  ...
}:

{
  subsystemAttrs,
  mainPackageName,
  mainPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  getSourceSpec,
  produceDerivation,

  ...
}@args:

let
  l = lib // builtins;

  getAllDependencies = pname: version:
    (args.getDependencies pname version)
    ++ (args.getCyclicDependencies pname version);

  getAllTransitiveDependencies = pname: version:
    let direct = getAllDependencies pname version; in
    l.unique (l.flatten (
      direct ++ (l.map (dep: getAllTransitiveDependencies dep.name dep.version) direct)
    ));

  vendorPackageDependencies = pname: version:
    let
      deps = getAllTransitiveDependencies pname version;

      makeSource = dep:
        let
          path = getSource dep.name dep.version;
          isGit = (getSourceSpec dep.name dep.version).type == "git";
        in {
          inherit path isGit dep;
          name = "${dep.name}-${dep.version}";
        };
      sources = l.map makeSource deps;

      findCrateSource = source:
        let
          inherit (pkgs) cargo jq;
          pkg = source.dep;
        in ''
          # If the target package is in a workspace, or if it's the top-level
          # crate, we should find the crate path using `cargo metadata`.
          crateCargoTOML=$(${cargo}/bin/cargo metadata --format-version 1 --no-deps --manifest-path $tree/Cargo.toml | \
            ${jq}/bin/jq -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path')
          # If the repository is not a workspace the package might be in a subdirectory.
          if [[ -z $crateCargoTOML ]]; then
            for manifest in $(find $tree -name "Cargo.toml"); do
              echo Looking at $manifest
              crateCargoTOML=$(${cargo}/bin/cargo metadata --format-version 1 --no-deps --manifest-path "$manifest" | ${jq}/bin/jq -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path' || :)
              if [[ ! -z $crateCargoTOML ]]; then
                break
              fi
            done
            if [[ -z $crateCargoTOML ]]; then
              >&2 echo "Cannot find path for crate '${pkg.name}-${pkg.version}' in the tree in: $tree"
              exit 1
            fi
          fi
          echo Found crate ${pkg.name} at $crateCargoTOML
          tree="$(dirname $crateCargoTOML)"
        '';
      makeScript = source:
        ''
          tree="${source.path}"
          ${l.optionalString source.isGit (findCrateSource source)}
          cp -prvd "$tree" $out/${source.name}
          chmod u+w $out/${source.name}
          ${l.optionalString source.isGit "printf '{\"files\":{},\"package\":null}' > \"$out/${source.name}/.cargo-checksum.json\""}
        '';
    in
    pkgs.runCommand "vendor-${pname}-${version}" {} ''
      mkdir -p $out

      ${
        l.concatMapStringsSep "\n"
        makeScript
        sources
       }
    '';
  
  # Generates a shell script that writes git vendor entries to .cargo/config.
  writeGitVendorEntries =
    let
      makeEntry = source:
        ''
        [source."${source.url}"]
        replace-with = "vendored-sources"
        git = "${source.url}"
        ${l.optionalString (source ? type) "${source.type} = \"${source.value}\""}
        '';
      entries = l.map makeEntry subsystemAttrs.gitSources;
    in ''
      cat >> ../.cargo/config <<EOF
      ${l.concatStringsSep "\n" entries}
      EOF
    '';

  buildPackage = pname: version:
    let
      src = getSource pname version;
      vendorDir = vendorPackageDependencies pname version;
    in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
      '';

      cargoVendorDir = "../nix-vendor";
      
      preBuild = ''
        ${writeGitVendorEntries}
      '';
    });
in
rec {
  packages =
    l.listToAttrs (
      l.map ({ name, version }: {
        inherit name;
        value = {
          ${version} = buildPackage name version;
        };
      }) subsystemAttrs.packages
    );

  defaultPackage = packages."${mainPackageName}"."${mainPackageVersion}";
}