// Builds the emails the Worker sends, as HTML and plain text with {{link}}
// in place of each person's link: `npm run emails`, which `npm run build`
// runs first. Each is written to emails/dist/ as JSON, which src/worker.ts
// imports.
import { mkdirSync, writeFileSync } from "node:fs";
import { render } from "@react-email/render";
import Confirm, { text } from "./confirm.tsx";

const out = new URL("./dist/", import.meta.url);
mkdirSync(out, { recursive: true });
const confirm = { html: await render(<Confirm link="{{link}}" />), text: text("{{link}}") };
writeFileSync(new URL("confirm.json", out), JSON.stringify(confirm));
console.log("Built the confirmation email in emails/dist/");
