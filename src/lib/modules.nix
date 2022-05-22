{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # imports a module.
  importModule = {
    file,
    validate ? _: {success = true;},
    ...
  } @ args: let
    filteredArgs = l.removeAttrs args ["file" "validate"];
    _module = import args.file;
    module =
      if l.isFunction _module
      then _module ({inherit dlib lib;} // filteredArgs)
      else throw "module file (${file}) must return a function that takes an attrset";
    _validationResult = validate module;
    throwMsg = msg:
      throw "module validation function ${msg}";
    validationResult =
      if ! l.isAttrs _validationResult
      then throwMsg "must return an attrset"
      else if ! _validationResult ? success
      then throwMsg "must return a boolean 'success' attribute"
      else if ! l.isBool _validationResult.success
      then throwMsg "must return a 'success' attribute that is a boolean"
      else if _validationResult.success == false && (! _validationResult ? error)
      then throwMsg "must return a string 'error' attribute on errors"
      else if _validationResult.success == false && (! l.isString _validationResult.error)
      then throwMsg "must return an 'error' attribute that is a string"
      else _validationResult;
  in
    if validationResult.success
    then module
    else throw validationResult.error;
in {
  inherit
    importModule
    ;
}
