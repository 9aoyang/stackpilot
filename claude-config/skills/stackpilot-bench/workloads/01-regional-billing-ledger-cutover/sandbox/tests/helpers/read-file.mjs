import fs from "node:fs";
import path from "node:path";

export function read(relativePath) {
  return fs.readFileSync(path.join(process.cwd(), relativePath), "utf8");
}

export function exists(relativePath) {
  return fs.existsSync(path.join(process.cwd(), relativePath));
}
