def normalizeWorkspaceDep:
  if ($workspaceDependencies."\(.key)" | type) == "object"
  then [., $workspaceDependencies."\(.key)"] | add
  else [., {"version":$workspaceDependencies."\(.key)"}] | add
  end
  # remove workspace option from the dependency
  | del(.workspace)
;

# normalizes workspace inherited dependencies for one list
def mapWorkspaceDepsFor(name):
  if has(name)
  then
    ."\(name)" = (
      ."\(name)"
      | to_entries
      | map(
        if (.value | type) == "object" and .value.workspace == true
        then .value = (.value | normalizeWorkspaceDep)
        else .
        end
      )
      | from_entries
    )
  else .
  end
;

# shorthand for normalizing all the dependencies list
def mapWorkspaceDeps:
  mapWorkspaceDepsFor("dependencies")
  | mapWorkspaceDepsFor("dev-dependencies")
  | mapWorkspaceDepsFor("build-dependencies")
;

# normalize workspace inherited deps
mapWorkspaceDeps
| if has("target")
  then
    # normalize workspace inherited deps in target specific deps
    .target = (
      .target
      | to_entries
      | map(.value = (.value | mapWorkspaceDeps))
      | from_entries
    )
  else .
  end
