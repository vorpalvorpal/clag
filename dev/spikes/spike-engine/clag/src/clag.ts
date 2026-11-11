/*
 * clag.ts -- spike: a Quarto engine extension that rewrites {{expr}} in prose
 * into `r expr` and then executes the document with knitr, by re-driving
 * Quarto's own rmd/rmd.R exactly as the built-in knitr engine does.
 *
 * Built-in reference: quarto-cli src/execute/rmd.ts (bundled in bin/quarto.js
 * as `knitrEngineDiscovery` + `callR`).
 */

import type {
  DependenciesOptions,
  EngineProjectContext,
  ExecuteOptions,
  ExecuteResult,
  ExecutionEngineDiscovery,
  ExecutionEngineInstance,
  ExecutionTarget,
  MappedString,
  PostProcessOptions,
  QuartoAPI,
  RunOptions,
} from "@quarto/types";

let quarto: QuartoAPI;

const kEngineName = "clag";
const kDebug = !!Deno.env.get("CLAG_DEBUG");

// ---------------------------------------------------------------------------
// debug: dump object shape (approach (a) probe)
// ---------------------------------------------------------------------------
function shape(obj: unknown, depth = 2, seen = new Set<unknown>()): unknown {
  if (obj === null || typeof obj !== "object") {
    return typeof obj === "function" ? "fn" : typeof obj;
  }
  if (seen.has(obj)) return "[cycle]";
  seen.add(obj);
  if (obj instanceof Map) {
    return { "[Map]": [...obj.keys()].map(String) };
  }
  if (depth <= 0) return "{...}";
  const out: Record<string, unknown> = {};
  for (const k of Object.keys(obj as Record<string, unknown>)) {
    out[k] = shape((obj as Record<string, unknown>)[k], depth - 1, seen);
  }
  return out;
}
function dbg(label: string, obj: unknown, depth = 2) {
  if (kDebug) {
    console.error(`[clag debug] ${label}: ` + JSON.stringify(shape(obj, depth)));
  }
}

// ---------------------------------------------------------------------------
// the transform: {{expr}} -> `r expr`, preserving a source map
// ---------------------------------------------------------------------------

interface Seg {
  newStart: number;
  newEnd: number;
  origStart: number;
  origEnd: number;
  identity: boolean;
}

// inline code span OR {{expr}} (not a {{< shortcode; no nested braces)
const kInlineRe = /(`+)[\s\S]*?\1|\{\{(?!<)([^{}\n]+?)\}\}/g;

export function transformText(src: string): { value: string; segs: Seg[] } {
  const segs: Seg[] = [];
  let out = "";
  let origPos = 0;
  const pushIdentity = (text: string) => {
    if (!text.length) return;
    segs.push({
      newStart: out.length,
      newEnd: out.length + text.length,
      origStart: origPos,
      origEnd: origPos + text.length,
      identity: true,
    });
    out += text;
    origPos += text.length;
  };
  const pushReplace = (origText: string, newText: string) => {
    segs.push({
      newStart: out.length,
      newEnd: out.length + newText.length,
      origStart: origPos,
      origEnd: origPos + origText.length,
      identity: false,
    });
    out += newText;
    origPos += origText.length;
  };

  // split keeping newlines
  const lines = src.match(/[^\n]*\n|[^\n]+$/g) ?? [];
  let fence: string | undefined; // closing fence marker when inside a fenced block
  let inYaml = false;
  let buf = ""; // prose buffer, transformed as a unit (inline code can't span blank-line paragraphs but keep it simple)

  const flushProse = () => {
    if (!buf) return;
    let last = 0;
    for (const m of buf.matchAll(kInlineRe)) {
      const idx = m.index!;
      pushIdentity(buf.slice(last, idx));
      if (m[2] !== undefined) {
        pushReplace(m[0], "`r " + m[2].trim() + "`");
      } else {
        pushIdentity(m[0]); // inline code span: leave alone
      }
      last = idx + m[0].length;
    }
    pushIdentity(buf.slice(last));
    buf = "";
  };

  lines.forEach((line, i) => {
    const bare = line.replace(/\r?\n$/, "");
    if (i === 0 && bare === "---") {
      inYaml = true;
      pushIdentity(line);
      return;
    }
    if (inYaml) {
      if (bare === "---" || bare === "...") inYaml = false;
      pushIdentity(line);
      return;
    }
    if (fence) {
      const m = bare.match(/^\s*(`{3,}|~{3,})\s*$/);
      if (m && m[1][0] === fence[0] && m[1].length >= fence.length) {
        fence = undefined;
      }
      pushIdentity(line);
      return;
    }
    const open = bare.match(/^\s*(`{3,}|~{3,})/);
    if (open) {
      flushProse();
      fence = open[1];
      pushIdentity(line);
      return;
    }
    buf += line;
  });
  flushProse();
  return { value: out, segs };
}

function transformMapped(md: MappedString): MappedString {
  const { value, segs } = transformText(md.value);
  if (value === md.value) return md;
  const map = (index: number, closest?: boolean) => {
    if (closest) index = Math.max(0, Math.min(index, value.length - 1));
    if (index < 0 || index >= value.length) return undefined;
    // binary search segment
    let lo = 0, hi = segs.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (segs[mid].newStart <= index) lo = mid;
      else hi = mid - 1;
    }
    const s = segs[lo];
    const off = index - s.newStart;
    const orig = s.identity
      ? s.origStart + off
      : s.origStart + Math.min(off, s.origEnd - s.origStart - 1);
    return md.map(orig, closest);
  };
  return { value, fileName: md.fileName, map };
}

// ---------------------------------------------------------------------------
// re-implementation of quarto's callR / rBinaryPath (rmd.ts, core/resources.ts)
// ---------------------------------------------------------------------------

let rscriptCache: string | undefined;
function rscriptPath(): string {
  if (rscriptCache) return rscriptCache;
  const isWin = Deno.build.os === "windows";
  const exe = isWin ? "Rscript.exe" : "Rscript";
  const exists = (p: string) => {
    try {
      Deno.statSync(p);
      return true;
    } catch {
      return false;
    }
  };
  const quartoR = Deno.env.get("QUARTO_R");
  if (quartoR && exists(quartoR)) {
    const dir = Deno.statSync(quartoR).isDirectory
      ? quartoR
      : quartoR.replace(/[\\/][^\\/]*$/, "");
    return (rscriptCache = `${dir}/${exe}`);
  }
  const rHome = Deno.env.get("R_HOME");
  if (rHome) {
    for (const p of [`${rHome}/bin/${exe}`, `${rHome}/bin/x64/${exe}`]) {
      if (exists(p)) return (rscriptCache = p);
    }
  }
  // fall back to PATH lookup by the OS (no Windows registry lookup here)
  return (rscriptCache = "Rscript");
}

function withinActiveRenv(): boolean {
  try {
    const profile = Deno.readTextFileSync(".Rprofile");
    const act = 'source("renv/activate.R")';
    return profile.includes(act) && !profile.includes("# " + act);
  } catch {
    return false;
  }
}

async function callR<T>(
  action: string,
  params: unknown,
  tempDir: string,
  projectDir?: string,
  quiet?: boolean,
  outputFilter?: (output: string) => string,
): Promise<T> {
  const cwd = withinActiveRenv() ? Deno.cwd() : projectDir ?? Deno.cwd();
  const resultsFile = Deno.makeTempFileSync({
    dir: tempDir,
    prefix: "r-results",
    suffix: ".json",
  });
  const input = JSON.stringify({ action, params, results: resultsFile, wd: cwd });
  const extraArgs = (Deno.env.get("QUARTO_KNITR_RSCRIPT_ARGS") || "")
    .split(",").filter((a) => a.trim() !== "");
  const result = await quarto.system.execProcess(
    {
      cmd: rscriptPath(),
      args: [...extraArgs, quarto.path.resource("rmd/rmd.R")],
      cwd,
      stderr: quiet ? "piped" : "inherit",
    },
    input,
    "stdout>stderr",
    (output) => (outputFilter ? outputFilter(output) : output),
  );
  if (result.success) {
    const results = await Deno.readTextFile(resultsFile);
    await Deno.remove(resultsFile);
    return JSON.parse(results) as T;
  } else {
    if (quiet) quarto.console.error(result.stderr || "");
    // built-in callR rejects with no value, which Quarto reports without a
    // stack trace; do the same
    return Promise.reject();
  }
}

// copy of rmd.ts resolveInlineExecute: `{r} expr` -> `r .QuartoInlineRender(expr)`
function resolveInlineExecute(code: string) {
  return quarto.text.executeInlineCodeHandler(
    "r",
    (expr) => "`r .QuartoInlineRender(" + expr + ")`",
  )(code);
}

function basename(p: string) {
  return p.replace(/^.*[\\/]/, "");
}

// ---------------------------------------------------------------------------
// engine
// ---------------------------------------------------------------------------

const clagEngineDiscovery: ExecutionEngineDiscovery = {
  init: (quartoAPI: QuartoAPI) => {
    quarto = quartoAPI;
    dbg("quarto API", quartoAPI, 2);
    if (kDebug) {
      const g = Object.getOwnPropertyNames(globalThis).filter((k) =>
        /quarto|engine|knitr/i.test(k)
      );
      console.error("[clag debug] globalThis matches:", JSON.stringify(g));
    }
  },
  name: kEngineName,
  defaultExt: ".qmd",
  defaultYaml: () => [],
  defaultContent: () => ["```{r}", "x <- 1", "```", "", "x is {{x}}."],
  validExtensions: () => [],
  // claimsFile is consulted (extension engines first) for every .qmd before
  // YAML/language-based selection, so it is the only hook that can grab a
  // .qmd that has {{expr}} prose but no {r} chunk. Respect an explicit
  // `engine:` (or `jupyter:` key) naming another engine.
  claimsFile: (file: string, ext: string) => {
    if (ext.toLowerCase() !== ".qmd") return false;
    if (Deno.env.get("CLAG_NO_CLAIMFILE")) return false; // spike test toggle
    let text: string;
    try {
      text = Deno.readTextFileSync(file);
    } catch {
      return false;
    }
    let yaml: Record<string, unknown> = {};
    try {
      yaml = quarto.markdownRegex.extractYaml(text) ?? {};
    } catch {
      return false;
    }
    const exec = yaml.execute as Record<string, unknown> | undefined;
    const declared = yaml.engine ?? exec?.engine;
    if (declared !== undefined) return declared === kEngineName;
    if (yaml.jupyter !== undefined) return false;
    return transformText(text).value !== text;
  },
  // knitr claims "r" with priority 1; claim with 2 so clag wins for any
  // document with {r} chunks when the extension is installed.
  claimsLanguage: (language: string) =>
    language.toLowerCase() === "r" ? 2 : false,
  canFreeze: true,
  generatesFigures: true,
  ignoreDirs: () => ["renv", "packrat", "rsconnect"],

  launch: (context: EngineProjectContext): ExecutionEngineInstance => {
    dbg("launch context", context, 1);
    if (kDebug) {
      for (const [k, v] of context.fileInformationCache) {
        console.error(
          `[clag debug] fileInformationCache ${k}: engine=${v.engine?.name}`,
        );
      }
    }
    const instance: ExecutionEngineInstance = {
      name: kEngineName,
      canFreeze: true,

      markdownForFile(file: string): Promise<MappedString> {
        return Promise.resolve(quarto.mappedString.fromFile(file));
      },

      target: async (file: string, _quiet?: boolean, markdown?: MappedString) => {
        const resolved = await context.resolveFullMarkdownForFile(
          instance,
          file,
          markdown,
        );
        const transformed = transformMapped(resolved);
        if (kDebug) {
          console.error("[clag debug] transformed markdown:\n" + transformed.value);
        }
        const target: ExecutionTarget = {
          source: file,
          input: file,
          markdown: transformed,
          metadata: quarto.markdownRegex.extractYaml(transformed.value),
        };
        return target;
      },

      partitionedMarkdown: (file: string) =>
        Promise.resolve(
          quarto.markdownRegex.partition(Deno.readTextFileSync(file)),
        ),

      execute: async (options: ExecuteOptions): Promise<ExecuteResult> => {
        const md = options.target.markdown;
        const inputBasename = basename(options.target.input);
        const inputStem = inputBasename.replace(/\.[^.]*$/, "");
        const result = await callR<ExecuteResult>(
          "execute",
          {
            ...options,
            target: undefined,
            project: undefined, // not serialisable / not needed by rmd.R
            input: options.target.input,
            markdown: resolveInlineExecute(md.value),
          },
          options.tempDir,
          options.project?.isSingleFile ? undefined : options.projectDir,
          options.quiet,
          (output) => {
            output = output.replaceAll(`${inputStem}.rmarkdown`, () => inputBasename);
            const m = output.match(/^Quitting from lines (\d+)-(\d+)/m);
            if (m) {
              const toIdx = quarto.text.lineColToIndex(md.value);
              const lc = (line: number) =>
                quarto.mappedString.indexToLineCol(
                  md,
                  toIdx({ line: line - 1, column: 0 }),
                ).line + 1;
              output = output.replace(
                /^Quitting from lines (\d+)-(\d+)/m,
                `\n\nQuitting from lines ${lc(Number(m[1]))}-${lc(Number(m[2]))}`,
              );
            }
            return output;
          },
        );
        if (Array.isArray(result.includes) && result.includes.length === 0) {
          result.includes = {};
        }
        dbg("execute result", result, 1);
        return result;
      },

      dependencies: (options: DependenciesOptions) =>
        callR(
          "dependencies",
          { ...options, target: undefined, input: options.target.input },
          options.tempDir,
          options.projectDir,
          options.quiet,
        ),

      postprocess: async (options: PostProcessOptions) => {
        quarto.text.postProcessRestorePreservedHtml(options);
        if (options.format.render?.["code-link"]) {
          await callR(
            "postprocess",
            { ...options, target: undefined, preserve: undefined, input: options.target.input },
            options.tempDir,
            options.projectDir,
            options.quiet,
          ).catch(() =>
            quarto.console.warning("clag: code-link postprocess failed")
          );
        }
      },

      run: (options: RunOptions) =>
        callR("run", options, options.tempDir, options.projectDir),
    };
    return instance;
  },
};

export default clagEngineDiscovery;
