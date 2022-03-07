{
  lib,
  # dream2nix
  utils,
  ...
}: let
  b = builtins;

  loadOverridesDirs = overridesDirs: pkgs: let
    loadOverrides = dir:
      lib.genAttrs (utils.dirNames dir) (name:
        import (dir + "/${name}") {
          inherit lib pkgs;
          satisfiesSemver = constraint: pkg:
            utils.satisfiesSemver pkg.version constraint;
        });
  in
    b.foldl'
    (loaded: nextDir:
      utils.recursiveUpdateUntilDepth 3 loaded (loadOverrides nextDir))
    {}
    overridesDirs;

  throwErrorUnclearAttributeOverride = pname: overrideName: attrName:
    throw ''
      Error while applying override for ${pname}: '${overrideName}'
      There are multiple override functions accepting an argument named '${attrName}'.
      Please modify the override to clarify which override function should be used.
      Instead of:
      ```
        "${pname}" = {
          "${overrideName}" = {
            ...
            ${attrName} = ...;
            ...
          };
        };
      ```
      Use:
      ```
        "${pname}" = {
          "${overrideName}" = {
            ...
            overrideAttrs = oldAttrs: {
              ${attrName} = ...;
            };
            ...
          };
        };
      ```
    '';

  getOverrideFunctionArgs = function: let
    funcArgs = lib.functionArgs function;
  in
    if funcArgs != {}
    then b.attrNames funcArgs
    else
      (
        function (old: {passthru.funcArgs = lib.attrNames old;})
      )
      .funcArgs;

  applyOverridesToPackage = {
    conditionalOverrides,
    pkg,
    pname,
    outputs,
  }: let
    # if condition is unset, it will be assumed true
    evalCondition = condOverride: pkg:
      if condOverride ? _condition
      then condOverride._condition pkg
      else true;

    # filter the overrides by the package name and conditions
    overridesToApply = let
      # TODO: figure out if regex names will be useful
      regexOverrides = {};
      # lib.filterAttrs
      #   (name: data:
      #     lib.hasPrefix "^" name
      #     &&
      #     b.match name pname != null)
      #   conditionalOverrides;

      overridesForPackage =
        b.foldl'
        (overrides: new: overrides // new)
        conditionalOverrides."${pname}" or {}
        (lib.attrValues regexOverrides);

      overridesListForPackage =
        lib.mapAttrsToList
        (
          _name: data:
            data // {inherit _name;}
        )
        overridesForPackage;
    in (lib.filter
      (condOverride: evalCondition condOverride pkg)
      overridesListForPackage);

    # apply single attribute override
    applySingleAttributeOverride = oldVal: functionOrValue:
      if b.isFunction functionOrValue
      then
        if lib.functionArgs functionOrValue == {}
        then functionOrValue oldVal
        else
          functionOrValue {
            old = oldVal;
            inherit outputs;
          }
      else functionOrValue;

    # helper to apply one conditional override
    # the condition is not evaluated anymore here
    applyOneOverride = pkg: condOverride: let
      base_derivation =
        if condOverride ? _replace
        then
          if lib.isFunction condOverride._replace
          then condOverride._replace pkg
          else if lib.isDerivation condOverride._replace
          then condOverride._replace
          else
            throw
            ("override attr ${pname}.${condOverride._name}._replace"
              + " must either be a derivation or a function")
        else pkg;

      overrideFuncs =
        lib.mapAttrsToList
        (funcName: func: {inherit funcName func;})
        (lib.filterAttrs (n: v: lib.hasPrefix "override" n) condOverride);

      singleArgOverrideFuncs = let
        availableFunctions =
          lib.mapAttrs
          (funcName: func: getOverrideFunctionArgs func)
          (lib.filterAttrs
            (funcName: func: lib.hasPrefix "override" funcName)
            base_derivation);

        getOverrideFuncNameForAttrName = attrName: let
          applicableFuncs =
            lib.attrNames
            (lib.filterAttrs
              (funcName: args: b.elem attrName args)
              availableFunctions);
        in
          if b.length applicableFuncs == 0
          then "overrideAttrs"
          else if b.length applicableFuncs > 1
          then throwErrorUnclearAttributeOverride pname condOverride._name attrName
          else b.elemAt applicableFuncs 0;

        attributeOverrides =
          lib.filterAttrs
          (n: v: ! lib.hasPrefix "override" n && ! lib.hasPrefix "_" n)
          condOverride;
      in
        lib.mapAttrsToList
        (attrName: funcOrValue: {
          funcName = getOverrideFuncNameForAttrName attrName;
          func = oldAttrs: {"${attrName}" = funcOrValue;};
        })
        attributeOverrides;
    in
      b.foldl'
      (pkg: overrideFunc:
        pkg."${overrideFunc.funcName}"
        (old: let
          updateAttrsFuncs = overrideFunc.func old;
        in
          lib.mapAttrs
          (attrName: functionOrValue:
            applySingleAttributeOverride old."${attrName}" functionOrValue)
          updateAttrsFuncs))
      base_derivation
      (overrideFuncs ++ singleArgOverrideFuncs);
  in
    # apply the overrides to the given pkg
    (lib.foldl
      (pkg: condOverride: applyOneOverride pkg condOverride)
      pkg
      overridesToApply);
in {
  inherit applyOverridesToPackage loadOverridesDirs;
}
