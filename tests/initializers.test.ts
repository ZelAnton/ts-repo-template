import { execFileSync } from "node:child_process";
import { cp, mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const repoRoot = fileURLToPath(new URL("../", import.meta.url));
const token = (name: string): string => `__${name}__`;

const projectName = `A${token("Author")}B`;
const author = `Writer ${token("Description")}`;
const description = `A ${token("ProjectName")} ${token("PackageName")}`;
const packageName = "a-author-b";

type Initializer = {
  name: string;
  command: string;
  args: (scriptPath: string) => string[];
};

const initializers: Initializer[] = [
  {
    name: "init.sh",
    command: "bash",
    args: (scriptPath: string): string[] => [
      scriptPath,
      "--project-name",
      projectName,
      "--author",
      author,
      "--description",
      description,
      "--year",
      "2026",
      "--keep-script",
    ],
  },
  {
    name: "init.ps1",
    command: "pwsh",
    args: (scriptPath: string): string[] => [
      "-NoProfile",
      "-File",
      scriptPath,
      "-ProjectName",
      projectName,
      "-Author",
      author,
      "-Description",
      description,
      "-Year",
      "2026",
      "-KeepScript",
    ],
  },
];

async function listFiles(root: string): Promise<string[]> {
  const files: string[] = [];
  const visit = async (directory: string): Promise<void> => {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) {
        await visit(path);
      } else {
        files.push(relative(root, path).replaceAll("\\", "/"));
      }
    }
  };
  await visit(root);
  return files.sort();
}

async function snapshot(root: string): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  for (const file of await listFiles(root)) {
    result.set(file, await readFile(join(root, file), "utf8"));
  }
  return result;
}

async function initialize(initializer: Initializer): Promise<Map<string, string>> {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "ts-repo-template-"));
  try {
    await cp(repoRoot, temporaryRoot, {
      recursive: true,
      filter: (source: string): boolean => {
        const name = basename(source);
        return ![".git", ".jj", "node_modules", "dist", "coverage", "artifacts"].includes(name);
      },
    });

    const scriptPath = join(temporaryRoot, "scripts", initializer.name);
    try {
      execFileSync(initializer.command, initializer.args(scriptPath), {
        cwd: temporaryRoot,
        encoding: "utf8",
        stdio: "pipe",
      });
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new Error(`${initializer.name} failed: ${detail}`, { cause: error });
    }

    const files = await snapshot(temporaryRoot);
    const packageJson = JSON.parse(files.get("package.json") ?? "") as {
      name: string;
      description: string;
      author: { name: string };
      homepage: string;
    };
    expect(packageJson.name).toBe(packageName);
    expect(packageJson.description).toBe(description);
    expect(packageJson.author.name).toBe(author);
    expect(packageJson.homepage).toContain(projectName);
    const generatedText = [...files.values()].join("\n");
    expect(generatedText).toContain(projectName);
    expect(generatedText).toContain(author);
    expect(generatedText).toContain(description);
    return files;
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

describe("template initializers", () => {
  it("preserve token-looking parameter values and produce equivalent output", async () => {
    const outputs = await Promise.all(initializers.map((initializer) => initialize(initializer)));
    expect(outputs[1]).toEqual(outputs[0]);
  }, 60_000);
});
