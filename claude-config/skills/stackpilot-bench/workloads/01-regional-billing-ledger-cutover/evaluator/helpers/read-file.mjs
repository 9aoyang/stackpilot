import fs from "node:fs";
import path from "node:path";

const root = process.env.STACKPILOT_EVAL_ROOT ?? process.cwd();

export function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

export function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}

export function sourceFiles() {
  return walk(path.join(root, "src"))
    .filter((filePath) => filePath.endsWith(".ts"))
    .map((filePath) => {
      const relativePath = path.relative(root, filePath);
      return {
        path: relativePath,
        text: fs.readFileSync(filePath, "utf8"),
      };
    });
}

export function sourceMatching(predicate) {
  return sourceFiles().filter(({ path: relativePath, text }) => predicate(relativePath, text));
}

export function allSource() {
  return sourceFiles()
    .map(({ path: relativePath, text }) => `\n// ${relativePath}\n${text}`)
    .join("\n");
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(fullPath);
    return [fullPath];
  });
}
