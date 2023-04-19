import os
import sys
import subprocess
import tempfile
import json
import dateutil.parser
from pathlib import Path

from .lock_file_from_report import lock_file_from_report
from .pypi_proxy import PypiProxy


__version__ = "1.0.0"


def get_max_date(snapshot_date):
    try:
        return int(snapshot_date)
    except ValueError:
        return dateutil.parser.parse(snapshot_date)


def prepare_venv(venv_path, pip_version, wheel_version):
    subprocess.run([sys.executable, "-m", "venv", venv_path], check=True)
    subprocess.run(
        [
            f"{venv_path}/bin/pip",
            "install",
            "--upgrade",
            f"pip=={pip_version}",
            f"wheel=={wheel_version}",
        ],
        check=True,
        stdout=sys.stderr,
        stderr=sys.stderr,
    )
    return venv_path


def fetch_pip_metadata():
    with open(sys.argv[1], "r") as f:
        args = json.load(f)

    with tempfile.TemporaryDirectory() as home:
        home = Path(home)

        print(
            f"selected maximum release date for python packages: {get_max_date(args['pypiSnapshotDate'])}",  # noqa: E501
            file=sys.stderr,
        )

        proxy = PypiProxy(
            executable=args["mitmProxy"],
            args=[
                "--ignore-hosts",
                ".*files.pythonhosted.org.*",
                "--script",
                args["filterPypiResponsesScript"],
            ],
            env={"pypiSnapshotDate": args["pypiSnapshotDate"], "HOME": home},
        )

        venv_path = prepare_venv(
            (home / ".venv").absolute(), args["pipVersion"], args["wheelVersion"]
        )  # noqa: 501

        flags = args["pipFlags"] + [
            "--proxy",
            f"https://localhost:{proxy.port}",
            "--progress-bar",
            "off",
            "--cert",
            proxy.cafile,
            "--report",
            str(home / "report.json"),
        ]
        for req in args["requirementsList"]:
            if req:
                flags.append(req)
        for req in args["requirementsFiles"]:
            if req:
                flags += ["-r", req]

        subprocess.run(
            [
                f"{venv_path}/bin/pip",
                "install",
                "--dry-run",
                "--ignore-installed",
                # "--use-feature=fast-deps",
                *flags,
            ],
            check=True,
            stdout=sys.stderr,
            stderr=sys.stderr,
        )
        proxy.kill()

        with open(home / "report.json", "r") as f:
            report = json.load(f)
        with open(os.getenv("out"), "w") as f:
            lock = lock_file_from_report(report)
            json.dump(lock, f, indent=2, sort_keys=True)
