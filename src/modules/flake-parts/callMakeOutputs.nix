{
  lib,
  makeOutputs,
}: input: let
  l = lib // builtins;

  mkProject = project:
    (l.removeAttrs project ["translatorArgs"])
    // {
      subsystemInfo = project.translatorArgs.${project.translator};
    };

  finalProjects = l.mapAttrs (_: mkProject) input.projects;

  makeOutputsArgs = {
    inherit
      (input)
      source
      pname
      settings
      packageOverrides
      sourceOverrides
      inject
      ;
    projects = finalProjects;
  };
in
  makeOutputs makeOutputsArgs
