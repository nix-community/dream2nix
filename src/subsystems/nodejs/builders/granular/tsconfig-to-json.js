try {
  require.resolve("typescript");
} catch (e) {
  process.exit(0);
}

const ts = require("typescript");
const fs = require("fs");

try {
  const data = fs.readFileSync("tsconfig.json", "utf8");
} catch (err) {
  console.error(err);
}

config = ts.parseConfigFileTextToJson(data);

// https://www.typescriptlang.org/tsconfig#preserveSymlinks
config.compilerOptions.preserveSymlinks = true;

fs.writeFileSync("tsconfig.json", JSON.stringify(config));
