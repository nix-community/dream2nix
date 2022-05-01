try {
  console.log(require.resolve("typescript"));
} catch(e) {
  console.error("typescript is not found");
  process.exit(e.code);
}

const ts = require("typescript")
const fs = require('fs')

try {
  const data = fs.readFileSync('/Users/joe/test.txt', 'utf8')
  console.log(data)
} catch (err) {
  console.error(err)
}

config = ts.parseConfigFileTextToJson(data)
newdata = JSON.stringify(config)
fs.writeFileSync('tsconfig.json', newdata);
