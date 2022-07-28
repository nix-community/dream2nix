import base64
import hashlib
import json
import os
import pathlib
import subprocess

# for initialization
def update_apt():
    subprocess.run(
        ["apt",
        "-o", "Acquire::AllowInsecureRepositories=1",
            "-o", "Dir::State::status=./status",
            "-o", "Dir::Etc=./etc/apt",
            "-o" ,"Dir::State=./state",
            "update"
        ])

def get_package_info_apt(name):
    result = subprocess.run(
        ["apt",
        "-o Acquire::AllowInsecureRepositories=1",
            "-o", "Dir::State::status=./status",
            "-o", "Dir::Etc=./etc/apt",
            "-o" "Dir::State=./state",
            "install", f"{name}", "--print-uris",
        ],
        stdout=subprocess.PIPE,
        text=True,
    )
    print(f"result {result.stdout}")
    with open('./deb-uris', 'w') as f:
        f.write(result.stdout)

    subprocess.run(
        ["apt",
        "-o", "Acquire::AllowInsecureRepositories=1",
            "-o", "Dir::State::status=./status",
            "-o", "Dir::Etc=./etc/apt",
            "-o", "Dir::Cache=./download",
            "-o", "Dir::State=./state",
            "install", f"{name}", "--download-only", "-y" ,"--allow-unauthenticated",
        ])

def main():
    update_apt()
    get_package_info_apt(os.environ.get("NAME"))

    with open("./deb-uris") as f:
        uris = f.readlines()

        dream_lock = dict(
            sources={},
            _generic={
                "subsystem": "debian",
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
                    bin = f.read()
                    hash = hashlib.sha256(bin)
                    digest = hash.digest()
                    base = base64.b64encode(digest)
                    decode = base.decode()
                    sha256 = f"sha256-{decode}"
                print(f"uri {uri}, deb: {deb}")
                (name, version, _) = deb.split("_")
                dream_lock["sources"][f"{name}"] = {
                    version: dict(
                        type="http",
                        url=uri.replace("http:", "https:").replace("'", ""),
                        hash=sha256,
                        version=version,
                    )
                }

    # add the version of the root package
    dream_lock["_generic"]["packages"][os.environ.get("NAME")] = list(
        dream_lock["sources"][os.environ.get("NAME")].keys()
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
