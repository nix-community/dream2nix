{
  callPackageDream,
  ...
}:
{
  python =  rec {

    default = simpleBuilder;

    simpleBuilder = callPackageDream ./python/simple-builder {};
  };

  nodejs =  rec {

    default = node2nix;

    node2nix = callPackageDream ./nodejs/node2nix {};
  };
  
}
