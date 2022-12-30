import json
import sys


def format_lock_str(lock):
    lockStr = json.dumps(lock, indent=2, sort_keys=True)
    lockStr = (
        lockStr.replace("[\n          ", "[ ")
        .replace('"\n        ]', '" ]')
        .replace(",\n          ", ", ")
    )
    return lockStr


if __name__ == "__main__":
    lock = json.loads(sys.stdin.read())
    print(format_lock_str(lock))
