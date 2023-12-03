{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  mkFlag = description:
    l.mkOption {
      inherit description;
      type = t.bool;
      default = false;
    };
in {
  options = {
    /*
    Helper option to define `flags`.
    This makes the syntax for defining flags simpler and at the same time
      prevents users to make mistakes like, for example, defining flags with
      other types than bool.

    This allows flags to be defined like this:
    {
      config.flagsOffered = {
        enableFoo = "builds with foo support";
        ...
      };
    }

    ... instead of this:
    {
      options.flags = {
        enableFoo = l.mkOption {
          type = t.bool;
          description = "builds with foo support";
          default = false;
        };
        ...
      }
    }

    */
    flagsOffered = l.mkOption {
      type = t.attrsOf t.str;
      default = {};
      description = ''
        declare flags that can be used to enable/disable features
      '';
    };

    # The flag options generated from `flagsOffered`
    flags = l.mkOption {
      type = t.submodule {
        options = l.mapAttrs (_: mkFlag) config.flagsOffered;
      };
      default = {};
      description = ''
        Enable/disable flags declared in `flagsOffered`
      '';
    };
  };
}
