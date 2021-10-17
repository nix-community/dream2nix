{
  lib,
  ...
}:
let

  b = builtins;

  exampleOverrides = {


    hello = {
      condition = old: if old.version > 3.0.0 then true else false;
      override = old: {
        patches = [];
      };
    };

  };

  applyOverridesToPackageArgs = conditionalOverrides: oldArgs:
    let

      # if condition is unset, it will be assumed true
      evalCondition = condAndOverride: oldArgs:
        if condAndOverride ? condition then
          condAndOverride.condition oldArgs
        else
          true;

      # filter the overrides by the package name and applying conditions
      overridesToApply =
        (lib.filterAttrs
          (name: condAndOverride:
              name == oldArgs.pname && condAndOverride.condition oldArgs)
          conditionalOverrides);
    in

      # apply the overrides to the given args and return teh overridden args
      lib.recursiveUpdate
        (lib.foldl
          (old: condAndOverride: old // (condAndOverride.override old))
          oldArgs
          (lib.attrValues overridesToApply))
        {
          passthru.appliedConditionalOverrides = lib.attrNames overridesToApply;
        };

in
{
  inherit applyOverridesToPackageArgs;
}
