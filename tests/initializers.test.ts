import { execFileSync } from "node:child_process";
import { cp, mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const repoRoot = fileURLToPath(new URL("../", import.meta.url));
const token = (name: string): string => `__${name}__`;

type InitializationParameters = {
  projectName: string;
  author: string;
  authorEmail: string;
  githubOwner: string;
  description: string;
};

type InitializationCase = {
  parameters: InitializationParameters;
  packageName: string;
};

const tokenLookingCase: InitializationCase = {
  parameters: {
    projectName: `A${token("Author")}B`,
    author: `Writer ${token("Description")}`,
    authorEmail: "writer@example.com",
    githubOwner: "example-owner",
    description: `A ${token("ProjectName")} ${token("PackageName")}`,
  },
  packageName: "a-author-b",
};

const controlCharacterCase: InitializationCase = {
  parameters: {
    projectName: "JsonControls",
    author: 'Author "quoted"\\path\r\nline\tcolumn\bbackspace',
    authorEmail: 'mail\\"box\r\n\t\b@example.com',
    githubOwner: 'owner\\"name\r\n\t\b',
    description:
      'Description "quoted"\\path\r\nline\tcolumn\bbackspace\fform-feed\u0001start-of-heading',
  },
  packageName: "jsoncontrols",
};

const repeatedBlockCase: InitializationCase = {
  parameters: {
    projectName: "A".repeat(32),
    author: "B".repeat(32),
    authorEmail: `${"c".repeat(32)}@example.com`,
    githubOwner: "d".repeat(32),
    description: " ".repeat(32),
  },
  packageName: "a".repeat(32),
};

type Initializer = {
  name: string;
  command: string;
  args: (scriptPath: string, parameters: InitializationParameters) => string[];
};

const initializers: Initializer[] = [
  {
    name: "init.sh",
    command: "bash",
    args: (_scriptPath: string, parameters: InitializationParameters): string[] => [
      "./scripts/init.sh",
      "--project-name",
      parameters.projectName,
      "--author",
      parameters.author,
      "--author-email",
      parameters.authorEmail,
      "--github-owner",
      parameters.githubOwner,
      "--description",
      parameters.description,
      "--year",
      "2026",
      "--keep-script",
    ],
  },
  {
    name: "init.ps1",
    command: "pwsh",
    args: (scriptPath: string, parameters: InitializationParameters): string[] => [
      "-NoProfile",
      "-File",
      scriptPath,
      "-ProjectName",
      parameters.projectName,
      "-Author",
      parameters.author,
      "-AuthorEmail",
      parameters.authorEmail,
      "-GitHubOwner",
      parameters.githubOwner,
      "-Description",
      parameters.description,
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

async function initialize(
  initializer: Initializer,
  testCase: InitializationCase,
): Promise<Map<string, string>> {
  const { parameters, packageName } = testCase;
  const temporaryRoot = await mkdtemp(join(tmpdir(), "ts-repo-template-"));
  const fixtureRoot = join(temporaryRoot, "repo");
  try {
    await cp(repoRoot, fixtureRoot, {
      recursive: true,
      filter: (source: string): boolean => {
        const name = basename(source);
        return ![".git", ".jj", ".work", "node_modules", "dist", "coverage", "artifacts"].includes(
          name,
        );
      },
    });

    const scriptPath = join(fixtureRoot, "scripts", initializer.name);
    try {
      execFileSync(initializer.command, initializer.args(scriptPath, parameters), {
        cwd: fixtureRoot,
        encoding: "utf8",
        stdio: "pipe",
      });
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new Error(`${initializer.name} failed: ${detail}`, { cause: error });
    }

    const files = await snapshot(fixtureRoot);
    const packageJson = JSON.parse(files.get("package.json") ?? "") as {
      name: string;
      description: string;
      author: { name: string; email: string };
      homepage: string;
    };
    expect(packageJson.name).toBe(packageName);
    expect(packageJson.description).toBe(parameters.description);
    expect(packageJson.author.name).toBe(parameters.author);
    expect(packageJson.author.email).toBe(parameters.authorEmail);
    expect(packageJson.homepage).toBe(
      `https://github.com/${parameters.githubOwner}/${parameters.projectName}#readme`,
    );
    const generatedText = [...files.values()].join("\n");
    expect(generatedText).toContain(parameters.projectName);
    expect(generatedText).toContain(parameters.author);
    expect(generatedText).toContain(parameters.authorEmail);
    expect(generatedText).toContain(parameters.githubOwner);
    expect(generatedText).toContain(parameters.description);
    return files;
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

describe("template initializers", () => {
  it("preserve token-looking parameter values and produce equivalent output", async () => {
    const outputs = await Promise.all(
      initializers.map((initializer) => initialize(initializer, tokenLookingCase)),
    );
    expect(outputs[1]).toEqual(outputs[0]);
  }, 60_000);

  it("round-trip JSON control characters and produce equivalent output", async () => {
    const outputs = await Promise.all(
      initializers.map((initializer) => initialize(initializer, controlCharacterCase)),
    );
    expect(outputs[1]).toEqual(outputs[0]);
  }, 60_000);

  it("round-trip repeated identical 16-byte blocks and produce equivalent output", async () => {
    const outputs = await Promise.all(
      initializers.map((initializer) => initialize(initializer, repeatedBlockCase)),
    );
    expect(outputs[1]).toEqual(outputs[0]);
  }, 60_000);
});
