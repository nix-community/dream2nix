import fs from "fs";
import path from "path";
import { abort } from "process";

const { out, FILESYSTEM } = process.env;
/**
 * A binary symlink called 'name' is created pointing to the executable in 'target'.
 *
 * @argument {[string, string]}
 */
function createBinEntry([name, target]) {
  const binDir = path.join(out, path.dirname(name));

  if (!fs.existsSync(binDir)) {
    fs.mkdirSync(binDir, { recursive: true }, () => {
      if (err) {
        console.error(err);
        abort();
      }
      console.log(`created dir: ${folder}`);
    });
  }

  const relTarget = path.relative(path.dirname(name), target);
  fs.chmod(target, fs.constants.S_IXUSR | fs.constants.S_IRUSR, () => {});
  fs.symlink(relTarget, path.join(out, name), (err) => {
    if (err) {
      console.error(err);
      abort();
    }
    console.log(`symlinked ${name} -> ${relTarget}`);
  });
}

/**
 * The source dist is copied to the target folder.
 *
 * @argument {[string, { source: string; bins: { [key: string]: string } } ] }
 */
function createEntry([folder, value]) {
  const finalPath = path.join(out, folder);

  fs.mkdirSync(finalPath, { recursive: true }, (err) => {
    if (err) {
      console.error(err);
      abort();
    }
    console.log(`created dir: ${folder}`);
  });

  fs.cpSync(value.source, finalPath, { recursive: true }, (err) => {
    if (err) {
      console.error(err);
      abort();
    }
    console.log(`copied: ${value.source} -> ${folder}`);
  });

  Object.entries(value.bins).forEach(createBinEntry);
}

Object.entries(JSON.parse(FILESYSTEM)).forEach(createEntry);
