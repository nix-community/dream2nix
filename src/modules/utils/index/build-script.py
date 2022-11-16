import json
import sys
import subprocess as sp
from pathlib import Path


def store_error(attrPath, category, text, name=None):
    with open(f"errors/{attrPath.replace('/', '--')}", 'w') as f:
        json.dump(
            dict(
                attrPath=attrPath,
                category=category,
                error=text,
                name=name,
            ),
            f,
        )


input = json.loads(sys.argv[1])
attr = input['attr']
attrPath = '.'.join(input['attrPath'])

# handle eval error
if "error" in input:
    error = input['error']
    print(
        f"Evaluation failed. attr: {attr} attrPath: {attrPath}\n"
        "Error:\n{error}",
        file=sys.stderr
    )
    store_error(attrPath, 'eval', error)
# try to build package
else:
    name = input['name']
    drvPath = input['drvPath']
    print(
        f"Building {name} attr: {attr} attrPath: {attrPath} "
        f"drvPath: ({drvPath})",
        file=sys.stderr
    )
    try:
        proc = sp.run(
            ['nix', 'build', '-L', drvPath],
            capture_output=True,
            check=True,
        )
        print(
            f"Finished {name}. attr: {attr} attrPath: {attrPath}",
            file=sys.stderr
        )
    # handle build error
    except sp.CalledProcessError as error:
        Path('errors').mkdir(exist_ok=True)
        print(
            f"Error while building {name}. attr: {attr} attrPath: {attrPath}",
            file=sys.stderr
        )
        store_error(attrPath, 'build', error.stderr.decode(), name)
