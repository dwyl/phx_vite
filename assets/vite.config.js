import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import fs from "fs";
import fg from "fast-glob";

const rootDir = path.resolve(import.meta.dirname);
const cssDir = path.resolve(rootDir, "css");
const jsDir = path.resolve(rootDir, "js");
const seoDir = path.resolve(rootDir, "seo");
const iconsDir = path.resolve(rootDir, "icons");
const wasmDir = path.resolve(rootDir, "wasm");
const srcImgDir = path.resolve(rootDir, "images");
const staticDir = path.resolve(rootDir, "../priv/static");

function copyStaticAssetsDev() {
  console.log("[vite.config] Copying non-fingerprinted assets in dev mode...");

  const copyTargets = [
    {
      srcDir: seoDir,
      destDir: staticDir, // place directly into priv/static
    },
    {
      srcDir: iconsDir,
      destDir: path.resolve(staticDir, "icons"),
    },
  ];

  copyTargets.forEach(({ srcDir, destDir }) => {
    if (!fs.existsSync(srcDir)) {
      console.log(`[vite.config] Source dir not found: ${srcDir}`);
      return;
    }
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }

    fg.sync(`${srcDir}/**/*.*`).forEach((srcPath) => {
      const relPath = path.relative(srcDir, srcPath);
      const destPath = path.join(destDir, relPath);
      const destSubdir = path.dirname(destPath);
      if (!fs.existsSync(destSubdir)) {
        fs.mkdirSync(destSubdir, { recursive: true });
      }

      fs.copyFileSync(srcPath, destPath);
    });
  });
}

function getEntryPoints() {
  return {
    app: "js/app.js",
    "app.css": "css/app.css",
  };
}

const buildOps = (mode) => ({
  target: ["esnext"],
  // Specify the directory to nest generated assets under (relative to build.outDir
  outDir: staticDir,
  cssCodeSplit: true, // Split CSS for better caching
  cssMinify: mode === "production" && "lightningcss", // Use lightningcss for CSS minification
  rollupOptions: {
    input:
      mode === "production"
        ? getEntryPoints()
        : {
            app: "js/app.js",
            "app.css": "css/app.css",
          },
    output: mode === "production" && {
      assetFileNames: "assets/[name]-[hash][extname]",
      chunkFileNames: "assets/[name]-[hash].js",
      entryFileNames: "assets/[name]-[hash].js",
    },
  },
  // generate a manifest file that contains a mapping of non-hashed asset filenames
  // to their hashed versions, which can then be used by a server framework
  // to render the correct asset links.
  manifest: true,
  path: ".vite/manifest.json",
  minify: mode === "production",
  emptyOutDir: true, // Remove old assets
  // sourcemap: mode === "development" ? "inline" : true,
  reportCompressedSize: true,
  assetsInlineLimit: 0,
});

const devServer = {
  cors: { origin: "http://localhost:4001" },
  allowedHosts: ["localhost"],
  strictPort: true,
  origin: "http://localhost:5174", // Vite dev server origin
  port: 5174, // Vite dev server port
  host: "localhost", // Vite dev server host
  watch: {
    ignored: ["**/priv/static/**", "**/lib/**", "**/*.ex", "**/*.exs"],
  },
};

export default defineConfig(({ command, mode }) => {
  if (command == "serve") {
    console.log("[vite.config] Running in development mode");
    copyStaticAssetsDev();
    process.stdin.on("close", () => process.exit(0));
    process.stdin.resume();
  }

  return {
    base: "/",
    plugins: [tailwindcss()],
    server: devServer,
    build: buildOps(mode),
    publicDir: false,
  };
});
