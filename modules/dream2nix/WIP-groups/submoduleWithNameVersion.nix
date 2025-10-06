# copied from nixpkgs with a single line added (see TODO)
{lib, ...}: let
  inherit
    (lib)
    isAttrs
    isFunction
    optionalAttrs
    last
    mkOptionType
    types
    attrNames
    ;

  inherit
    (lib.types)
    path
    defaultFunctor
    ;

  submoduleWith = {
    modules,
    specialArgs ? {},
    shorthandOnlyDefinesConfig ? false,
    description ? null,
    class ? null,
  } @ attrs: let
    inherit (lib.modules) evalModules;

    allModules = defs:
      map (
        {
          value,
          file,
        }:
          if isAttrs value && shorthandOnlyDefinesConfig
          then {
            _file = file;
            config = value;
          }
          else {
            _file = file;
            imports = [value];
          }
      )
      defs;

    base = evalModules {
      inherit class specialArgs;
      modules =
        [
          {
            # This is a work-around for the fact that some sub-modules,
            # such as the one included in an attribute set, expects an "args"
            # attribute to be given to the sub-module. As the option
            # evaluation does not have any specific attribute name yet, we
            # provide a default for the documentation and the freeform type.
            #
            # This is necessary as some option declaration might use the
            # "name" attribute given as argument of the submodule and use it
            # as the default of option declarations.
            #
            # We use lookalike unicode single angle quotation marks because
            # of the docbook transformation the options receive. In all uses
            # &gt; and &lt; wouldn't be encoded correctly so the encoded values
            # would be used, and use of `<` and `>` would break the XML document.
            # It shouldn't cause an issue since this is cosmetic for the manual.
            _module.args.name = lib.mkOptionDefault "‹name›";
          }
        ]
        ++ modules;
    };

    inherit (base._module) freeformType;

    name = "submodule";
  in
    mkOptionType {
      inherit name;
      description =
        if description != null
        then description
        else freeformType.description or name;
      check = x: isAttrs x || isFunction x || path.check x;
      merge = loc: defs:
        (base.extendModules {
          modules =
            [
              {
                # this is the only line that was added
                # TODO: think about ways to upstream this
                _module.args.name = lib.elemAt loc ((lib.length loc) - 2);
                _module.args.version = lib.last loc;
              }
            ]
            ++ allModules defs;
          prefix = loc;
        })
        .config;
      emptyValue = {value = {};};
      getSubOptions = prefix:
        (base.extendModules
          {inherit prefix;})
        .options
        // optionalAttrs (freeformType != null) {
          # Expose the sub options of the freeform type. Note that the option
          # discovery doesn't care about the attribute name used here, so this
          # is just to avoid conflicts with potential options from the submodule
          _freeformOptions = freeformType.getSubOptions prefix;
        };
      getSubModules = modules;
      substSubModules = m:
        submoduleWith (attrs
          // {
            modules = m;
          });
      nestedTypes = lib.optionalAttrs (freeformType != null) {
        inherit freeformType;
      };
      functor =
        defaultFunctor name
        // {
          type = types.submoduleWith;
          payload = {
            inherit modules class specialArgs shorthandOnlyDefinesConfig description;
          };
          binOp = lhs: rhs: {
            class =
              # `or null` was added for backwards compatibility only. `class` is
              # always set in the current version of the module system.
              if lhs.class or null == null
              then rhs.class or null
              else if rhs.class or null == null
              then lhs.class or null
              else if lhs.class or null == rhs.class
              then lhs.class or null
              else throw "A submoduleWith option is declared multiple times with conflicting class values \"${toString lhs.class}\" and \"${toString rhs.class}\".";
            modules = lhs.modules ++ rhs.modules;
            specialArgs = let
              intersecting = builtins.intersectAttrs lhs.specialArgs rhs.specialArgs;
            in
              if intersecting == {}
              then lhs.specialArgs // rhs.specialArgs
              else throw "A submoduleWith option is declared multiple times with the same specialArgs \"${toString (attrNames intersecting)}\"";
            shorthandOnlyDefinesConfig =
              if lhs.shorthandOnlyDefinesConfig == null
              then rhs.shorthandOnlyDefinesConfig
              else if rhs.shorthandOnlyDefinesConfig == null
              then lhs.shorthandOnlyDefinesConfig
              else if lhs.shorthandOnlyDefinesConfig == rhs.shorthandOnlyDefinesConfig
              then lhs.shorthandOnlyDefinesConfig
              else throw "A submoduleWith option is declared multiple times with conflicting shorthandOnlyDefinesConfig values";
            description =
              if lhs.description == null
              then rhs.description
              else if rhs.description == null
              then lhs.description
              else if lhs.description == rhs.description
              then lhs.description
              else throw "A submoduleWith option is declared multiple times with conflicting descriptions";
          };
        };
    };
in
  submoduleWith
