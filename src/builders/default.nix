{
  callPackage,
  ...
}:
{
  python =  rec {

    default = simpleBuilder;

    simpleBuilder = callPackage ./python/simple-builder {};
  };

  nodejs =  rec {

    default = node2nix;

    node2nix = callPackage ./nodejs/node2nix {};
  };
  
}
