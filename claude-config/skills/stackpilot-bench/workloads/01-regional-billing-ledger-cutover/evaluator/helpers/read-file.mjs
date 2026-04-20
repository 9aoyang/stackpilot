import fs from "node:fs";
import path from "node:path";

const root = process.env.STACKPILOT_EVAL_ROOT ?? process.cwd();

export function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

export function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}
