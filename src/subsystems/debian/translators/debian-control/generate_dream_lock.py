import json
import os
import pathlib


def main():
    # TODO parse versions
    VERSION = "UNKNOWN"

    dream_lock = dict(
        sources={},
        _generic={
            "subsystem": "debian",
            "defaultPackage": os.environ.get("NAME"),
            "packages": {
                os.environ.get("NAME"): VERSION,
            },
            "sourcesAggregatedHash": None,
            "location": "",
        },
        _subsystem={},
    )

    dream_lock["_subsystem"] = dict(control_inputs=json.loads(os.environ.get("deps")))

    # dump dream lock to $outputFile
    outputFile = os.environ.get("outputFile")
    dirPath = pathlib.Path(os.path.dirname(outputFile))
    dirPath.mkdir(parents=True, exist_ok=True)
    with open(outputFile, "w") as lock:
        json.dump(dream_lock, lock, indent=2)


if __name__ == "__main__":
    main()
