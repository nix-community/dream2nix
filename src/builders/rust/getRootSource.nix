{
  getSourceSpec,
  getSource,
}:
pname: version:
  let
    _spec = getSourceSpec pname version;
    spec = builtins.trace _spec _spec;
  in
    if spec.type == "path" then
      getSource spec.rootName spec.rootVersion
    else
      getSource pname version