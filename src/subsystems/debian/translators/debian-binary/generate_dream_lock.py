import json
import os
import pathlib
import base64
import hashlib


def main():
    with open("./deb-uris") as f:
        uris = f.readlines()

        dream_lock = dict(
            sources={},
            _generic={
                "subsystem": "debian-binary",
                "defaultPackage": os.environ.get("NAME"),
                "packages": {
                    os.environ.get("NAME"): os.environ.get("VERSION"),
                },
                "sourcesAggregatedHash": None,
                "location": "",
            },
            _subsystem={},
        )

        for line in uris:
            # print(line)
            split_lines = line.split(" ")
            if len(split_lines) == 4:
                (uri, deb, _, _) = split_lines
                with open(f"./download/archives/{deb}", "rb") as f:
                    # print(f"decode {deb}")
                    bin = f.read()
                    hash = hashlib.sha256(bin)
                    digest = hash.digest()
                    base = base64.b64encode(digest)
                    print(base)
                    decode = base.decode()
                    print(decode)
                    sha256 = f"sha256-{base64.b64encode(hashlib.sha256(f.read()).digest()).decode()}"
                print(f"uri {uri}, deb: {deb}")
                (name, version, _) = deb.split("_")
                dream_lock["sources"][name] = {
                    version: dict(
                        type="http",
                        url="uri",
                        sha256=sha256,
                    )
                }

    # add the version of the root package
    dream_lock["_generic"]["packages"][os.environ.get("NAME")] = list(
        dream_lock["sources"]["htop"].keys()
    )[0]

    # dump dream lock to $ouputFile
    outputFile = (os.environ.get("outputFile"),)
    # FIXME: Why is this a tuple?
    outputFile = outputFile[0]
    # print(f"outputFile: {outputFile}")
    dirPath = pathlib.Path(os.path.dirname(outputFile))
    dirPath.mkdir(parents=True, exist_ok=True)
    with open(outputFile, "w") as lock:
        json.dump(dream_lock, lock, indent=2)
    print(list(dream_lock["sources"]["htop"].keys())[0])


if __name__ == "__main__":
    main()
