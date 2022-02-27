{
  getSourceSpec,
  getSource,
}:
pname: version:
  let
    spec = getSourceSpec pname version;
  in
    if spec.type == "path" then
      getSource spec.rootName spec.rootVersion
    else
      getSource pname version