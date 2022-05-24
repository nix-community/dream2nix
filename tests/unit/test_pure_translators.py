import nix_ffi
import os
import pytest


def get_projects_to_test():
  tests = nix_ffi.eval(
    'subsystems.allTranslators',
    wrapper_code = '''
      {result}: let
        lib = (import <nixpkgs> {}).lib;
        l = lib // builtins;
      in
        l.flatten (
          l.map
          (
            translator:
              l.map
                (source: {
                  source = l.toString source;
                  translator = translator.name;
                  inherit (translator) subsystem type;
                })
                (translator.generateUnitTestsForProjects or []))
          )
          result
        )
    ''',
  )
  result = []
  for test in tests:
    if test['type'] == 'all':
      continue
    result.append(dict(
      project = dict(
        name="test",
        relPath="",
        translator=test['translator'],
        subsystemInfo={},
      ),
      translator=test['translator'],
      source = test['source'],
      subsystem = test['subsystem'],
      type = test['type'],
    ))
  return result


projects = get_projects_to_test()


def check_format_dependencies(dependencies):
  assert isinstance(dependencies, list)
  for dep in dependencies:
    assert set(dep.keys()) == {'name', 'version'}
    assert isinstance(dep['name'], str)
    assert len(dep['name']) > 0
    assert isinstance(dep['version'], str)
    assert len(dep['version']) > 0

def check_format_sourceSpec(sourceSpec):
  assert isinstance(sourceSpec, dict)
  assert 'type' in sourceSpec

@pytest.mark.parametrize("p", projects)
def test_packageName(p):
  defaultPackage = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.defaultPackage
    ''',
  )
  assert isinstance(defaultPackage, str)
  assert len(defaultPackage) > 0

@pytest.mark.parametrize("p", projects)
def test_exportedPackages(p):
  exportedPackages = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.exportedPackages
    ''',
  )
  assert isinstance(exportedPackages, dict)
  assert len(exportedPackages) > 0

@pytest.mark.parametrize("p", projects)
def test_extraDependencies(p):
  extraDependencies = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.extraDependencies
    ''',
  )
  assert isinstance(extraDependencies, list)
  for extra_dep in extraDependencies:
    assert set(extra_dep.keys()) == {"dependencies", "name", "version"}
    assert isinstance(extra_dep['name'], str)
    assert len(extra_dep['name']) > 0
    assert isinstance(extra_dep['version'], str)
    assert len(extra_dep['version']) > 0
    check_format_dependencies(extra_dep['dependencies'])

@pytest.mark.parametrize("p", projects)
def test_extraObjects(p):
  extraObjects = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.extraObjects
    ''',
  )
  assert isinstance(extraObjects, list)
  for extra_obj in extraObjects:
    assert set(extra_obj.keys()) == \
      {'name', 'version', 'dependencies', 'sourceSpec'}
    assert isinstance(extra_obj['name'], str)
    assert len(extra_obj['name']) > 0
    assert isinstance(extra_obj['version'], str)
    assert len(extra_obj['version']) > 0
    check_format_dependencies(extra_obj['dependencies'])
    check_format_sourceSpec(extra_obj['sourceSpec'])

@pytest.mark.parametrize("p", projects)
def test_location(p):
  location = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.location
    ''',
  )
  assert isinstance(location, str)

@pytest.mark.parametrize("p", projects)
def test_serializedRawObjects(p):
  serializedRawObjects = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:

      result.inputs.serializedRawObjects
    ''',
  )
  assert isinstance(serializedRawObjects, list)
  for raw_obj in serializedRawObjects:
    assert isinstance(raw_obj, dict)

@pytest.mark.parametrize("p", projects)
def test_subsystemName(p):
  subsystemName = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.subsystemName
    ''',
  )
  assert isinstance(subsystemName, str)
  assert len(subsystemName) > 0

@pytest.mark.parametrize("p", projects)
def test_subsystemAttrs(p):
  subsystemAttrs = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.subsystemAttrs
    ''',
  )
  assert isinstance(subsystemAttrs, dict)

@pytest.mark.parametrize("p", projects)
def test_translatorName(p):
  translatorName = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      result.inputs.translatorName
    ''',
  )
  assert isinstance(translatorName, str)
  assert len(translatorName) > 0

@pytest.mark.parametrize("p", projects)
def test_extractors(p):
  finalObjects = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      let
        l = builtins;
        inputs = result.inputs;
        rawObjects = inputs.serializedRawObjects;

        finalObjects =
          l.map
          (rawObj: let
            finalObj =
              l.mapAttrs
              (key: extractFunc: extractFunc rawObj finalObj)
              inputs.extractors;
          in
            finalObj)
          rawObjects;
      in
        finalObjects ++ (inputs.extraObjects or [])
    ''',
  )
  assert isinstance(finalObjects, list)
  assert len(finalObjects) > 0
  for finalObj in finalObjects:
    assert set(finalObj.keys()) == \
      {'name', 'version', 'sourceSpec', 'dependencies'}
    check_format_dependencies(finalObj['dependencies'])
    check_format_sourceSpec(finalObj['sourceSpec'])

@pytest.mark.parametrize("p", projects)
def test_keys(p):
  objectsByKey = nix_ffi.eval(
    f"subsystems.{p['subsystem']}.translators.{p['translator']}.translate",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result}:
      let
        l = builtins;
        inputs = result.inputs;
        rawObjects = inputs.serializedRawObjects;

        finalObjects =
          l.map
          (rawObj: let
            finalObj =
              {inherit rawObj;}
              // l.mapAttrs
              (key: extractFunc: extractFunc rawObj finalObj)
              inputs.extractors;
          in
            finalObj)
          rawObjects;

        objectsByKey =
          l.mapAttrs
          (key: keyFunc:
            l.foldl'
            (merged: finalObj:
              merged
              // {"${keyFunc finalObj.rawObj finalObj}" = finalObj;})
            {}
            (finalObjects ++ (inputs.extraObjects or [])))
          inputs.keys;
      in
        objectsByKey
    ''',
  )
  assert isinstance(objectsByKey, dict)
  for key_name, objects in objectsByKey.items():
    for finalObj in objects.values():
      assert set(finalObj.keys()) == \
        {'name', 'version', 'sourceSpec', 'dependencies', 'rawObj'}
      check_format_dependencies(finalObj['dependencies'])
      check_format_sourceSpec(finalObj['sourceSpec'])
