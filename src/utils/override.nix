{
  lib,

  # dream2nix
  utils,
  ...
}:
let

  b = builtins;

  loadOverridesDirs = overridesDirs: pkgs:
    let
      loadOverrides = dir:
        lib.genAttrs (utils.dirNames dir) (name:
          import (dir + "/${name}") {
            inherit lib pkgs;
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

  applyOverridesToPackage = conditionalOverrides: pkg: pname:
    # if ! conditionalOverrides ? "${pname}" then
    #   pkg
    # else
      
      let

        # if condition is unset, it will be assumed true
        evalCondition = condOverride: pkg:
            if condOverride ? _condition then
              condOverride._condition pkg
            else
              true;

        # filter the overrides by the package name and conditions
        overridesToApply =
          let
            regexOverrides =
              lib.filterAttrs
                (name: data:
                  lib.hasPrefix "^" name
                  &&
                  b.match name pname != null)
                conditionalOverrides;

            overridesForPackage =
              b.foldl'
                (overrides: new: overrides // new)
                conditionalOverrides."${pname}" or {}
                (lib.attrValues regexOverrides);

            overridesListForPackage =
              lib.mapAttrsToList
                (_name: data: data // { inherit _name; })
                overridesForPackage;
          in
            (lib.filter
              (condOverride: evalCondition condOverride pkg)
              overridesListForPackage);

        # apply single attribute override
        applySingleAttributeOverride = oldVal: functionOrValue:
           if b.isFunction functionOrValue then
              functionOrValue oldVal
            else
              functionOrValue;

        # helper to apply one conditional override
        # the condition is not evaluated anymore here
        applyOneOverride = pkg: condOverride:
          let
            overrideFuncs =
              lib.mapAttrsToList
                (funcName: func: { inherit funcName func; })
                (lib.filterAttrs (n: v: lib.hasPrefix "override" n) condOverride);

            singleArgOverrideFuncs =
              let
                availableFunctions =
                  lib.mapAttrs
                    (funcName: func: lib.attrNames (lib.functionArgs func))
                    (lib.filterAttrs
                      (funcName: func: lib.hasPrefix "override" funcName)
                      pkg);

                getOverrideFuncNameForAttrName = attrName:
                  let
                    applicableFuncs =
                      lib.attrNames
                        (lib.filterAttrs
                          (funcName: args: b.elem attrName args)
                          availableFunctions);
                  in
                    if b.length applicableFuncs == 0 then
                      "overrideAttrs"
                    else if b.length applicableFuncs >= 1 then
                      throwErrorUnclearAttributeOverride pname condOverride._name attrName
                    else
                      b.elemAt applicableFuncs 0;

                attributeOverrides =
                  lib.filterAttrs
                    (n: v: ! lib.hasPrefix "override" n && ! lib.hasPrefix "_" n)
                    condOverride;
              
              in
                lib.mapAttrsToList
                    (attrName: funcOrValue: {
                      funcName = getOverrideFuncNameForAttrName attrName;
                      func = oldAttrs: { "${attrName}" = funcOrValue; };
                    })
                    attributeOverrides;

          in
            b.foldl'
              (pkg: overrideFunc:
                pkg."${overrideFunc.funcName}"
                (old:
                  let
                    updateAttrsFuncs = overrideFunc.func old;
                  in
                    lib.mapAttrs
                      (attrName: functionOrValue:
                        applySingleAttributeOverride old."${attrName}" functionOrValue)
                      updateAttrsFuncs))
              pkg
              (overrideFuncs ++ singleArgOverrideFuncs);
      in
        # apply the overrides to the given pkg
        (lib.foldl
          (pkg: condOverride: applyOneOverride pkg condOverride)
          pkg
          overridesToApply);

in
{
  inherit applyOverridesToPackage loadOverridesDirs;
}
