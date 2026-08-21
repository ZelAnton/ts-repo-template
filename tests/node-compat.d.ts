declare module "node:child_process" {
  export function execFileSync(
    file: string,
    args: readonly string[],
    options: { cwd: string; encoding: "utf8"; stdio: "pipe" },
  ): string;
}

declare module "node:fs/promises" {
  type DirectoryEntry = {
    name: string;
    isDirectory(): boolean;
  };

  export function cp(
    source: string,
    destination: string,
    options: {
      recursive: true;
      filter: (source: string) => boolean;
    },
  ): Promise<void>;
  export function mkdtemp(prefix: string): Promise<string>;
  export function readdir(
    path: string,
    options: { withFileTypes: true },
  ): Promise<DirectoryEntry[]>;
  export function readFile(path: string, encoding: "utf8"): Promise<string>;
  export function rm(path: string, options: { recursive: true; force: true }): Promise<void>;
}

declare module "node:os" {
  export function tmpdir(): string;
}

declare module "node:path" {
  export function basename(path: string): string;
  export function join(...paths: string[]): string;
  export function relative(from: string, to: string): string;
}

declare module "node:url" {
  export function fileURLToPath(url: string | URL): string;
}

interface ImportMeta {
  readonly url: string;
}

declare class URL {
  public constructor(url: string, base?: string | URL);
}
