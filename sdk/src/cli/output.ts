// Printing for people and, with --json, for programs such as coding agents.

const colors = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (code: string) => (text: string) => (colors ? `\u001b[${code}m${text}\u001b[0m` : text);

export const style = {
  bold: paint("1"),
  dim: paint("2"),
  red: paint("31"),
  green: paint("32"),
  yellow: paint("33"),
  cyan: paint("36"),
};

/** A failure to report without a stack trace, with the details that explain it. */
export class CommandError extends Error {
  constructor(message: string, readonly details: string[] = []) {
    super(message);
  }
}

export function printJSON(value: unknown): void {
  process.stdout.write(JSON.stringify(value, null, 2) + "\n");
}

export function printError(error: unknown, json: boolean): void {
  const message = error instanceof Error ? error.message : String(error);
  const details = error instanceof CommandError ? error.details : [];
  if (json) {
    printJSON({ ok: false, error: message, details });
    return;
  }
  process.stderr.write(`${style.red("✗")} ${message}\n`);
  for (const detail of details) process.stderr.write(`  ${detail}\n`);
}
