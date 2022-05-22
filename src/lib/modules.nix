{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # imports a module.
  importModule = {
    file,
    validate ? _: true,
    ...
  } @ args: let
    filteredArgs = l.removeAttrs args ["file" "validate"];
    _module = import args.file;
    module =
      if l.isFunction _module
      then _module ({inherit dlib lib;} // filteredArgs)
      else throw "module file (${file}) must return a function that takes an attrset";
  in
    l.seq (validate module) module;
in {
  inherit
    importModule
    ;
}
