{
  description = "(modules only) dream2nix: Automate reproducible packaging for various language ecosystems";

  outputs = _: let
    modulesDir = ./.;

    inherit
      (builtins)
      attrNames
      concatMap
      listToAttrs
      mapAttrs
      readDir
      stringLength
      substring
      ;

    nameValuePair = name: value: {inherit name value;};

    filterAttrs =
      # Predicate taking an attribute name and an attribute value, which returns `true` to include the attribute, or `false` to exclude the attribute.
      pred:
      # The attribute set to filter
      set:
        listToAttrs (concatMap (name: let
          v = set.${name};
        in
          if pred name v
          then [(nameValuePair name v)]
          else []) (attrNames set));

    moduleKinds =
      filterAttrs (_: type: type == "directory") (readDir modulesDir);

    mapAttrs' =
      # A function, given an attribute's name and value, returns a new `nameValuePair`.
      f:
      # Attribute set to map over.
      set:
        listToAttrs (map (attr: f attr set.${attr}) (attrNames set));

    removeSuffix =
      # Suffix to remove if it matches
      suffix:
      # Input string
      str: (let
        sufLen = stringLength suffix;
        sLen = stringLength str;
      in
        if sufLen <= sLen && suffix == substring (sLen - sufLen) sufLen str
        then substring 0 (sLen - sufLen) str
        else str);

    mapModules = kind:
      mapAttrs'
      (fn: _: {
        name = removeSuffix ".nix" fn;
        value = modulesDir + "/${kind}/${fn}";
      })
      (readDir (modulesDir + "/${kind}"));
  in {
    modules = mapAttrs (kind: _: mapModules kind) moduleKinds;
  };
}
