// Converts package lock version 2 to easy-to-parse json for the translator
// Format of lockfile is at https://docs.npmjs.com/cli/v8/configuring-npm/package-lock-json/

// TODO warn if package name is same as dependency name
// TODO handle devOptional - right now it will always install

const fs = require("fs");

const lock = JSON.parse(fs.readFileSync(process.argv[2]));

const pkgs = lock.packages;
const deps = {};

lock.self = pkgs[""];

// First part is always "" and path doesn't start with /
const toPath = parts => parts.join("/node_modules/").slice(1);

// As a side-effect, it registers the dep
const resolveDep = (name, parts, isOptional) => {
  const p = [...parts];
  let dep;
  while (p.length && !(dep = pkgs[toPath([...p, name])])) p.pop();
  if (!dep)
    if (isOptional) return;
    else
      throw new Error(
        `Cannot resolve dependency ${name} from ${parts.join(" > ")}`
      );
  if (!deps[name]) deps[name] = {};
  deps[name][dep.version] = dep;
  return { name, version: dep.version };
};

for (const [path, pkg] of Object.entries(pkgs)) {
  const parts = path.split(/\/?node_modules\//);
  //   pkg.pname = parts.length === 1 ? pkg.name : parts.at(-1);
  const dependencies = Object.keys(pkg.dependencies || {}).map(depName =>
    resolveDep(depName, parts)
  );
  const peerDependencies = Object.keys(pkg.peerDependencies || {}).map(
    depName => resolveDep(depName, parts, true)
  );
  const optionalDependencies = Object.keys(pkg.optionalDependencies || {}).map(
    depName => resolveDep(depName, parts, true)
  );
  const devDependencies = Object.keys(pkg.devDependencies || {}).map(depName =>
    resolveDep(depName, parts, true)
  );
  // The peer dependencies are treated as direct dependencies because the symlinking correctly
  // lets node treat them as only a single dependency, and npm already resolved everything
  // so peer dependencies are shared.
  pkg.deps = [
    ...dependencies,
    ...peerDependencies,
    ...optionalDependencies,
    ...devDependencies,
  ].filter(Boolean);
}

lock.allDeps = [];
for (const [pname, versions] of Object.entries(deps))
  for (const dep of Object.values(versions)) {
    const {
      version,
      resolved: url,
      integrity: hash,
      dev,
      optional,
      devOptional,
      inBundle,
      os,
      deps,
    } = dep;
    lock.allDeps.push({
      pname,
      version,
      url,
      hash,
      dev,
      optional,
      devOptional,
      inBundle,
      os,
      deps,
    });
  }
lock.packages = undefined;
lock.dependencies = undefined;
fs.writeFileSync(process.argv[3], JSON.stringify(lock, null, 2));
