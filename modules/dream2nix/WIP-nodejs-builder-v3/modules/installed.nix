{
  dream2nix,
  # _module.args
  plent,
  packageName,
  bins,
  nodejs,
  jq,
  dist,
  prepared-prod,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];
  config = {
    inherit (plent) version;
    name = packageName + "-installed";
    env = {
      BINS = builtins.toJSON bins;
    };
    mkDerivation = {
      src = dist;
      nativeBuildInputs = [jq];
      buildInputs = [nodejs];
      configurePhase = ''
        cp -r ${prepared-prod}/node_modules node_modules
      '';
      installPhase = ''
        mkdir -p $out/lib/node_modules/${packageName}
        cp -r . $out/lib/node_modules/${packageName}

        mkdir -p $out/bin
        echo $BINS | jq 'to_entries | map("ln -s $out/lib/node_modules/${packageName}/\(.value) $out/bin/\(.key); ") | .[]' -r | bash
      '';
    };
  };
}
