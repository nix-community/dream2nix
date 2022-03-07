{
  getSourceSpec,
  getSource,
  getRoot,
  ...
}: rec {
  getRootSource = pname: version: let
    root = getRoot pname version;
  in
    getSource root.pname root.version;
}
