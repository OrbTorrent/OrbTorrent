import net from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";
import { CommandError } from "./output.js";
import { sdkVersion } from "./paths.js";

// OrbTorrent listens for `orb dev` and `orb run` on a socket only your account
// can open, while "Allow development extensions" is on (Extensions → Develop).
// Messages are JSON objects, one per line.

export type Message = { type: string; [key: string]: any };

// ORB_APP=dev reaches OrbTorrent Dev instead, the build used while developing
// OrbTorrent itself.
const appName = process.env.ORB_APP === "dev" ? "OrbTorrent Dev" : "OrbTorrent";

export const socketPath = join(homedir(), "Library", "Application Support", appName, "dev.sock");

const notReachable = new CommandError(`${appName} isn't reachable.`, [
  `Open ${appName}, then on the Develop tab of its Extensions page (in the sidebar) turn on “Allow development extensions”.`,
]);

export class AppConnection {
  private buffer = "";
  private listeners = new Set<(message: Message) => void>();
  private closed = false;

  private constructor(private readonly socket: net.Socket) {
    socket.setEncoding("utf8");
    socket.on("data", (chunk: string) => {
      this.buffer += chunk;
      let newline: number;
      while ((newline = this.buffer.indexOf("\n")) >= 0) {
        const line = this.buffer.slice(0, newline);
        this.buffer = this.buffer.slice(newline + 1);
        if (!line.trim()) continue;
        let message: Message;
        try {
          message = JSON.parse(line);
        } catch {
          continue;
        }
        for (const listener of [...this.listeners]) listener(message);
      }
    });
    socket.on("close", () => {
      this.closed = true;
      for (const listener of [...this.listeners]) listener({ type: "closed" });
    });
  }

  static async open(): Promise<AppConnection> {
    const socket = await new Promise<net.Socket>((resolve, reject) => {
      const socket = net.createConnection(socketPath);
      socket.once("connect", () => resolve(socket));
      socket.once("error", () => reject(notReachable));
    });
    const connection = new AppConnection(socket);
    const hello = await connection.request({ type: "hello", client: "orb", version: sdkVersion }, ["hello"]);
    if (hello.type !== "hello") throw notReachable;
    return connection;
  }

  send(message: Message): void {
    this.socket.write(JSON.stringify(message) + "\n");
  }

  /** Calls `listener` with every message until it returns true. */
  listen(listener: (message: Message) => boolean | void): Promise<void> {
    return new Promise((resolve) => {
      const wrapped = (message: Message) => {
        if (listener(message) === true || message.type === "closed") {
          this.listeners.delete(wrapped);
          resolve();
        }
      };
      this.listeners.add(wrapped);
    });
  }

  /** Sends a message and waits for a reply of one of `types`, or an error. */
  async request(message: Message, types: string[], onOther?: (message: Message) => void): Promise<Message> {
    let reply: Message | undefined;
    const waiting = this.listen((incoming) => {
      if (types.includes(incoming.type) || incoming.type === "error" || incoming.type === "closed") {
        reply = incoming;
        return true;
      }
      onOther?.(incoming);
    });
    this.send(message);
    await waiting;
    if (!reply || reply.type === "closed") throw new CommandError("OrbTorrent closed the connection.");
    if (reply.type === "error") throw new CommandError(reply.message, reply.details ?? []);
    return reply;
  }

  close(): void {
    if (!this.closed) this.socket.end();
  }
}
