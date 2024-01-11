import fs from "fs";
import { abort } from "process";
import { execSync } from "child_process";

const { TRUSTED } = process.env;

/**@type {string[]} */
const trusted = JSON.parse(TRUSTED);
console.log({ trusted });

/**
 * @type {fs.Dirent[]}*/
const packageJsonFiles = fs
  .readdirSync(
    "./node_modules",
    { recursive: true, withFileTypes: true },
    (error) => {
      console.error({ error });
      abort();
    }
  )
  .filter(
    (/**@type {fs.Dirent}*/ entry) =>
      entry.isFile() &&
      entry.name === "package.json" &&
      // Reduce the number of packageJson files that we need to parse.
      // Note: The list may still have some false positives. They will be skipped later
      trusted.some((trustedName) => entry.path.endsWith(trustedName))
  );

// If a dependency is trusted
// Run the following scripts if present
//
// preinstall
// install
// postinstall
// prepublish
// preprepare
// prepare
// postprepare
//
// The lifecycle scripts run only after node_modules are completely initialized with ALL modules
//
// Lifecycle scripts can execute arbitrary code.
// They often violate isolation between packages which makes them potentially insecure.

const lifecycleScripts = [
  "preinstall",
  "install",
  "postinstall",
  "prepublish",
  "preprepare",
  "prepare",
  "postprepare",
];

packageJsonFiles.forEach((pjs) => {
  const content = fs.readFileSync(`${pjs.path}/${pjs.name}`);

  /**@type {{scripts?: { [k: string]: string}, name: string }}*/
  const info = JSON.parse(content.toString());
  const { scripts, name: packageName } = info;

  // Skip false positives
  if (trusted.includes(packageName)) {
    const run =
      scripts &&
      Object.entries(scripts).filter(([k]) =>
        lifecycleScripts.some((s) => s === k)
      );
    if (run) {
      run.forEach(([scriptName, command]) => {
        console.log(`${packageName} - ${scriptName}: ${command}`);
        try {
          const result = execSync(command, { cwd: pjs.path });
          console.log(result.toString());
        } catch (err) {
          console.error(
            `Could not execute lifecycle script '${scriptName}' for ${packageName} (See Trusted Dependencies)`
          );
          console.error(err);
        }
      });
    } else {
      console.warn(
        `Trusted package ${packageName} doesnt have any lifecycle scripts. This entry does not have any affect.`
      );
    }
  }
});
