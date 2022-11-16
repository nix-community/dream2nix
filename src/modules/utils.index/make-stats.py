import json
import os

error_files = os.listdir('errors')
eval_errors = 0
build_errors = 0
all_errors = {}

for file in error_files:
    with open(f"errors/{file}") as f:
        error = json.load(f)
    # add error to all_errors
    all_errors[error['attrPath']] = error
    # count error types
    if error['category'] == 'eval':
        eval_errors += 1
    else:
        build_errors += 1

num_errors = eval_errors + build_errors

stats = dict(
    errors=num_errors,
    errors_eval=eval_errors,
    errors_build=build_errors,
)

with open("errors.json", 'w') as f:
    json.dump(all_errors, f)

with open('stats.json', 'w') as f:
    json.dump(stats, f)
