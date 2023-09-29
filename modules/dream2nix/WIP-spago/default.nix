{lib, dream2nix, config, packageSets, ...}:
let
  l = lib // builtins;

  purescript-overlay = builtins.getFlake "github:thomashoneyman/purescript-overlay/dbf63923b2d7a8ed03e962db9f450e6fa61fb526"; 
  inherit (purescript-overlay.packages.${config.deps.stdenv.system}) purs spago-unstable;
  # FIXME wait fix by Dave and then remove lines above
  # inherit (dream2nix.inputs.purescript-overlay.packages.${config.deps.stdenv.system}) purs spago-unstable;

  registry-index = config.deps.fetchFromGitHub {
    owner = "purescript";
    repo = "registry-index";
    rev = "e1529b1338796f81d8401e3562674bc6490b2ea9";
    hash = "sha256-/GeBrbl4g9qXCLld/2rK/zLDmpOmAZouBKJFIpQhjoU=";
  };

  registry = config.deps.fetchFromGitHub {
    owner = "purescript";
    repo = "registry";
    rev = "cf70a36e1233f71bd4a39d516a76dd25129184e3";
    hash = "sha256-h7wcsL8ubXSK7JAm+5UFq+9b5FDiRyz5F/mzRsaHJvI=";
  };
  
  writers = import ../../../pkgs/writers {
    inherit lib;
    inherit
      (config.deps)
      bash
      coreutils
      gawk
      writeScript
      writeScriptBin
      path
      ;
  };

  cfg = config.spago;
  
  lock = config.lock.content.spago-lock;

  mkTarball = depName: config.deps.runCommand "${depName}-tarball" {} ''
    mkdir ${depName}-${l.removePrefix "v" lock.${depName}.version}
    cd ${depName}-${l.removePrefix "v" lock.${depName}.version}
    cp -r ${cfg.sources.${depName}}/* .
    cd ..
    tar -cvzf $out .
  '';
  
  installSource = depName: dep: ''
    ln -s ${dep} .spago/packages/${depName}-${lock.${depName}.version}
    mkdir -p $HOME/.cache/spago-nodejs/packages/${depName}      
    cp ${mkTarball depName} $HOME/.cache/spago-nodejs/packages/${depName}/${l.removePrefix "v" lock.${depName}.version}.tar.gz
  '';

  installSources = l.mapAttrsToList installSource cfg.sources;

in {
  imports = [
    dream2nix.modules.dream2nix.core
    dream2nix.modules.dream2nix.mkDerivation
    ./interface.nix
  ];

  spago.sources = l.mapAttrs (depName: dep: builtins.fetchGit (l.trace (builtins.toJSON dep) {
    inherit (dep) rev;
    url = dep.repo;
  })) config.lock.content.spago-lock;

  mkDerivation = {
    nativeBuildInputs = [
      spago-unstable
      purs
      config.deps.git
      config.deps.breakpointHook
      config.deps.esbuild
      config.deps.yq-go
    ];
    buildInputs = [
      config.deps.nodejs
    ];
    buildPhase = ''
      export HOME="$(realpath .)"
      mkdir -p "$HOME/.cache/spago-nodejs"
      ln -s ${registry} "$HOME/.cache/spago-nodejs/registry"
      ln -s ${registry-index} "$HOME/.cache/spago-nodejs/registry-index"
      mkdir -p .spago/packages
      ${toString installSources}
      spago bundle --verbose
      OUTFILE="$(yq -r '.package.bundle.outfile // "index.js"' spago.yaml)"
      mkdir -p $out/bin	
      cp "$OUTFILE" "$out/bin/$OUTFILE"	
    '';
  };
  
  lock.fields.spago-lock.script = writers.writePureShellScript [
    config.deps.coreutils
    config.deps.curl
    config.deps.gnutar
    config.deps.gzip
    config.deps.yq-go
    config.deps.python3
    config.deps.git
  ]
    ''
    set -euo pipefail
    mkdir $TMPDIR/package-sets
    cd $TMPDIR/package-sets
    curl -fL https://github.com/purescript/package-sets/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
    yq -o=json < ${config.spago.spagoYamlFile} > spago.json
    python3 ${./lock.py}
  '';

    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit
          (nixpkgs)
	  stdenv
          coreutils
	  curl
	  writeScript
	  writeScriptBin
	  bash
	  path
	  gawk
	  gnutar
	  gzip
	  yq-go
	  python3
	  git
	  esbuild  # used by spago bundle
	  fetchFromGitHub
	  breakpointHook
	  runCommand
	  nodejs
          ;
      };
}
