#!/usr/bin/env node
/** Ensures GitHub Pages serves _astro and other paths Jekyll would ignore. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dist = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "www", "dist");
fs.writeFileSync(path.join(dist, ".nojekyll"), "", "utf8");
console.log("postprocess-pages: wrote .nojekyll");
