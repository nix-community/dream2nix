{
  lib,
  specialArgs,
  ...
}: module:
lib.mkOption {
  type = lib.types.submoduleWith {
    inherit specialArgs;
    modules = [
      module
    ];
  };
}
