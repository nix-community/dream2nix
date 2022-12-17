{
  config,
  lib,
  ...
}: let
  b = builtins;
  l = config.lib;

  loadOverridesDirs = overridesDirs: pkgs: let
    loadOverrides = dir:
      l.genAttrs (config.dlib.dirNames dir) (name:
        import (dir + "/${name}") {
          inherit (config) lib pkgs;
          satisfiesSemver = constraint: pkg:
            config.utils.satisfiesSemver pkg.version constraint;
        });
  in
    b.foldl'
    (loaded: nextDir:
      config.dlib.recursiveUpdateUntilDepth 3 loaded (loadOverrides nextDir))
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
        function (old: {passthru.funcArgs = l.attrNames old;})
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
      regexOverrides =
        l.filterAttrs
        (name: data:
          l.hasPrefix "^" name
          && b.match name pname != null)
        conditionalOverrides;

      overridesForPackage =
        b.foldl'
        (overrides: new: overrides // new)
        conditionalOverrides."${pname}" or {}
        (l.attrValues regexOverrides);

      overridesListForPackage =
        l.mapAttrsToList
        (
          _name: data:
            data // {inherit _name;}
        )
        overridesForPackage;
    in (l.filter
      (condOverride: evalCondition condOverride pkg)
      overridesListForPackage);

    # apply single attribute override
    applySingleAttributeOverride = oldVal: functionOrValue:
      if b.isFunction functionOrValue
      then
        if l.functionArgs functionOrValue == {}
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
          if l.isFunction condOverride._replace
          then condOverride._replace pkg
          else if l.isDerivation condOverride._replace
          then condOverride._replace
          else
            throw
            ("override attr ${pname}.${condOverride._name}._replace"
              + " must either be a derivation or a function")
        else pkg;

      overrideFuncs =
        l.mapAttrsToList
        (funcName: func: {inherit funcName func;})
        (l.filterAttrs (
            n: v:
              l.hasPrefix "override" n
              && (! b.elem n ["overrideDerivation" "overridePythonAttrs"])
          )
          condOverride);

      singleArgOverrideFuncs = let
        availableFunctions =
          l.mapAttrs
          (funcName: func: getOverrideFunctionArgs func)
          (l.filterAttrs
            (funcName: func: l.hasPrefix "override" funcName && (! b.elem funcName ["overrideDerivation" "overridePythonAttrs" "overrideRustToolchain"]))
            base_derivation);

        getOverrideFuncNameForAttrName = attrName: let
          applicableFuncs =
            l.attrNames
            (l.filterAttrs
              (funcName: args: b.elem attrName args)
              availableFunctions);
        in
          if b.length applicableFuncs == 0
          then "overrideAttrs"
          else if b.length applicableFuncs > 1
          then throwErrorUnclearAttributeOverride pname condOverride._name attrName
          else b.elemAt applicableFuncs 0;

        attributeOverrides =
          l.filterAttrs
          (n: v: ! l.hasPrefix "override" n && ! l.hasPrefix "_" n)
          condOverride;
      in
        l.mapAttrsToList
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
          l.mapAttrs
          (attrName: functionOrValue:
            applySingleAttributeOverride old."${attrName}" functionOrValue)
          updateAttrsFuncs))
      base_derivation
      (overrideFuncs ++ singleArgOverrideFuncs);
  in
    # apply the overrides to the given pkg
    l.foldl
    (pkg: condOverride: applyOneOverride pkg condOverride)
    pkg
    overridesToApply;
in {
  config.utils = {
    inherit applyOverridesToPackage loadOverridesDirs;
  };
}
