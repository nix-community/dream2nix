{
  lib,
  ...
}:
let

  b = builtins;

  exampleOverrides = {

    hello = [
      {
        description = "patch hello";
        condition = pkg: if pkg.version > 3.0.0 then true else false;
        overrideAttrs = old: {
          patches = [];
        };
        override = old: {
          withPython = false;
        };
      }
    ];
  };

  applyOverridesToPackage = conditionalOverrides: pkg: pname:
    if ! conditionalOverrides ? "${pname}" then
      pkg
    else
      
      let

        # if condition is unset, it will be assumed true
        evalCondition = condOverride: pkg:
          if condOverride ? condition then
            condOverride.condition pkg
          else
            true;

        # filter the overrides by the package name and conditions
        overridesToApply =
          (lib.filter
            (condOverride: evalCondition condOverride pkg)
            conditionalOverrides."${pname}");

        # helper to apply one conditional override
        # the condition is not evaluated anymore here
        applyOneOverride = pkg: condOverride:
          let
            overrideFuncs =
              lib.mapAttrsToList
              (funcName: func: { inherit funcName func; })
              (lib.filterAttrs (n: v: lib.hasPrefix "override" n) condOverride);
          in
            b.foldl'
              (pkg: overrideFunc: pkg."${overrideFunc.funcName}" overrideFunc.func)
              pkg
              overrideFuncs;
      in
        # apply the overrides to the given pkg
        (lib.foldl
          (pkg: condOverride: applyOneOverride pkg condOverride)
          pkg
          overridesToApply);

in
{
  inherit applyOverridesToPackage;
}
