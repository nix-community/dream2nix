{
  inputs,
  cell,
}: {
  default = cell.packages.app;
  app = {
    source = inputs.src;
    projects = {
      prettier = {
        name = "prettier";
        subsystem = "nodejs";
        translator = "yarn-lock";
      };
    };
  };
}
