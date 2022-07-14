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

// Here we discover what NPM resolved each dependency to
// The peer dependencies are treated as direct dependencies because the symlinking correctly
// lets node treat them as only a single dependency, and npm already resolved everything
// so peer dependencies are correctly shared.
for (const [path, pkg] of Object.entries(pkgs)) {
  const depmap = {};
  const parts = path.split(/\/?node_modules\//);
  const handleDeps = (obj, isOptional) => {
    if (obj)
      for (const depName of Object.keys(obj))
        if (!depmap[depName]) {
          const resolved = resolveDep(depName, parts, isOptional);
          if (resolved) depmap[depName] = resolved;
        }
  };
  handleDeps(pkg.dependencies, false);
  handleDeps(pkg.peerDependencies, true);
  handleDeps(pkg.optionalDependencies, true);
  // This is the only place where optional peer deps are mentioned
  handleDeps(pkg.peerDependenciesMeta, true);
  handleDeps(pkg.devDependencies, true);
  pkg.deps = Object.values(depmap);
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
    if (!url)
      throw new Error(
        `Dependency ${pname}@${version} has no resolved property, package-lock is invalid`
      );
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
