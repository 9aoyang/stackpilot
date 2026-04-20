export const logger = {
  info(fields: Record<string, unknown>, message: string) {
    process.stdout.write(JSON.stringify({ level: "info", message, ...fields }) + "\n");
  },
  warn(fields: Record<string, unknown>, message: string) {
    process.stderr.write(JSON.stringify({ level: "warn", message, ...fields }) + "\n");
  },
  error(fields: Record<string, unknown>, message: string) {
    process.stderr.write(JSON.stringify({ level: "error", message, ...fields }) + "\n");
  },
};
