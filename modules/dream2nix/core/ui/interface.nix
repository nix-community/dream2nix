{
  config,
  lib,
  ...
}: {
  options = {
    /*
    This allows to define name & version in the top-level instead of under
      the `public` attrs, allowing users to reference name and version elsewhere
      via `${config.name}` instead of `${config.public.name}`.
    This is not only more convenient but currently also circumvents issues with
      infinite recursions that can be triggered by referencing
      `${config.public.name}`.
    The top-level of `public` contains an entry for each output, and is
      therefore dynamic. This makes `public` non-lazy as it requires evaluating
      `outputs` before it can be constructed.
    If `outputs` depend on the name and version of the package, which it might
      in IFD scenarios, then name and version itself cannot be read from
      `public` without triggering an infinite recursion.
    This problem could be circumvented by removing the top-level output attrs
      from `public` as proposed in
      https://github.com/NixOS/nix/issues/6507#issuecomment-1474664755 .
    After this we could still offer compatibility by adding a `compat` module
      that adds the output fields to `public` and re-exposes the result under
      a new field `compat`.
    */
    name = lib.mkOption {
      type = lib.types.str;
      description = "The name of the package";
    };
    version = lib.mkOption {
      type = lib.types.str;
      description = "The version of the package";
    };
    drvPath = lib.mkOption {
      type = lib.types.path;
      internal = true;
      description = "The path to the derivation of the package";
    };
    type = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "The type attribute required by nix to identify derivations";
    };
  };
}
