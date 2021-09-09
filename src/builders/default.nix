{
  callPackage,
}:
rec {
  python = rec {

    default = simpleBuilder;

    simpleBuilder = callPackage ./python/simple-builder {};
  };
  
}
