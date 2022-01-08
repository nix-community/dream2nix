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
  
  getGitDep = pname: version:
    l.findFirst
    (dep: dep.name == pname && dep.version == version)
    null
    subsystemAttrs.gitDeps;

  # TODO: this is shared between the translator and this builder
  # we should dedup this somehow (maybe put in a common library for Rust subsystem?)
  recurseFiles = path:
    l.flatten (
      l.mapAttrsToList
      (n: v: if v == "directory" then recurseFiles "${path}/${n}" else "${path}/${n}")
      (l.readDir path)
    );
  getAllFiles = dirs: l.flatten (l.map recurseFiles dirs);
  getCargoTomlPaths = l.filter (path: l.baseNameOf path == "Cargo.toml");
  getCargoTomls = l.map (path: { inherit path; value = l.fromTOML (l.readFile path); });
  getCargoPackages = l.filter (toml: l.hasAttrByPath [ "package" "name" ] toml.value);
  findCratePath = cargoPackages: name:
    l.dirOf (
      l.findFirst
      (toml: toml.value.package.name == name)
      (throw "could not find crate ${name}")
      cargoPackages
    ).path;
  
  vendorPackageDependencies = pname: version:
    let
      deps = getAllTransitiveDependencies pname version;

      makeSource = dep:
        let
          srcPath = getSource dep.name dep.version;
          isGit = (getGitDep dep.name dep.version) != null;
          path =
            if isGit
            then let
              # These locate the actual path of the crate in the source...
              # This is important because git dependencies may or may not be in a
              # workspace with complex crate hierarchies. This can locate the crate
              # accurately using Cargo.toml files.
              cargoPackages = l.pipe [ srcPath ] [ getAllFiles getCargoTomlPaths getCargoTomls getCargoPackages ];
            in findCratePath cargoPackages dep.name
            else srcPath;
        in {
          inherit path isGit;
          name = "${dep.name}-${dep.version}";
        };
      sources = l.map makeSource deps;

      makeScript = source:
        ''
          cp -prvd "${source.path}" $out/${source.name}
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
  writeGitVendorEntries = pname: version:
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
      writeGitVendorEntriesScript = writeGitVendorEntries pname version;
    in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
      '';

      cargoVendorDir = "../nix-vendor";
      
      preBuild = ''
        ${writeGitVendorEntriesScript}
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