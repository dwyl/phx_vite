# ExVite


An example of a configuration to use `Vite` with `Phoenix LiveView`.

Start with:

```elixir
mix phx.new my_app --no-assets
```

Use the mix task to install `Vite` with `tailwind` by default, but not `daisyui` nor `heroicons` as supplied by `Phoenix 1.8`.

```
mix vite.install
```


>[!NOTE]
You may use the option `css` to install a copy of the `daisyui` and `heroicons` files as provided by `Phoenix 1.8` into the __/assets/vendor__ folder and set the __app.css__ file.

```elixir
mix vite.install --css heroicons --css daisyui
```



>[!NOTE]
You can bring in what you want with the option flags `dep` or `dev-dep`.

>[!WARNING]
It is recommend to add packages manually, with:
 `pnpm add (-D) xxx --prefix assets`.
Indeed, `pnpm` can output warnings which you might miss. For example, in case you are using native `Node.js` addons which need to be compiled, you need to pass them to the field `onlyBuiltDependencies`. 

The output is:

```elixir
Assets setup started for ex_streams (ExStreams)...
[...]
Assets installation completed!

✅ What was added to your project:
   • Environment config in config/config.exs
   • Vite watcher configuration in config/dev.exs
   • Vite configuration file at assets/vite.config.js
   • Updated root layout template at lib/ex_streams_web/components/layouts/root.html.heex
   • Vite helper module at lib/ex_streams_web/vite.ex
   • pnpm workspace configuration at pnpm-workspace.yaml
   • Package.json with Phoenix workspace dependencies
   • Asset directories: assets/icons/ and assets/seo/ with placeholder files
   • Updated static_paths in lib/ex_streams_web.ex to include 'icons'
   • Client libraries: lightweight-charts, topbar
   • Dev dependencies: Tailwind CSS, Vite, DaisyUI, and build tools

🚀 Next steps:
   • Check 'static_paths/0' in your endpoint config
   • Use 'Vite.path/1' in your code to define the source of your assets
   • Run 'mix phx.server' to start your Phoenix server
   • Vite dev server will start automatically on http://localhost:5173
```

> [!IMPORTANT] 
It warns you should use `Vite.path("path-to-my-static-file")`, which works in DEV and PROD mode.


 __How?__ The documentation: <https://vite.dev/guide/backend-integration.html>


__Why?__ `Vite`does not bundle the code in development which means the dev server is fast to start, and your changes will be updated instantly.
You can easily bring in plugins such as VitePWA with Workbox, or ZSTD compression, client-side SVG integration, React, Svelte, Solid... and [more](https://github.com/vitejs/awesome-vite#plugins).

Catching the Google trend?!

![Screenshot 2025-07-08 at 17 46 42](https://github.com/user-attachments/assets/812e72bb-f0f7-4de1-8b9c-1cfe727bfdc7)

__What?__ In DEV mode, you will be running a `Vite` dev server on port 5173 and `Phoenix` on port 4000.

>[!NOTE]
In DEV mode, you should see (at least) two WebSocket:

```
ws://localhost:4000/phoenix/live_reload/socket/websocket?vsn=2.0.0
ws://localhost:5173/?token=yFGCVgkhJxQg
```

and the network inspection shows:

```
app.css -> http://localhost:5173/css/app.css
app.js  -> http://localhost:5173/js/app.js
```

In DEV mode, `Vite` serves your asssets from __/assets/{js,images,...}__.

Your non-fingerprinted assets, ie __/assets/seo/robots.txt, /assets/seo/sitemap.xml, /assets/icons/favicon.ico...__ and copied into __/priv/static/{icons}__.

>[!NOTE]
In PROD mode, `Vite` bundles the code, with tree-shaking... into the folder __/priv/static/assets/__.

We will use the helper `Vite.path/1` for this.

In your Dockerfile, use:

```
pnpm vite build --mode production --config vite.config.js
```


Check: <https://github.com/dwyl/phx_vite/blob/main/lib/mix/tasks/vite_install.ex>

## Manual Setup

- in "/", create `pnpm-workspace.yaml` (use "yaml", not "yml")
- go to "/assets", run `pnpm init` and set `"type": "module"`
- add/remove packages with `pnpm add -D xxx` or `pnpm remove xxx`
- go to "/" and run `pnpm install`.
- change the __app_name__ in "Vite.ex" and the folder name in "assets/css/app.css"


### Static assets

All your static assets should be organised in the "/assets" folder with the structure:

```
/assest/{js,css,seo, fonts, icons, images, wasm,...}
```

>[!IMPORTANT]
Do not add anything in the "/priv/static" folder as it will be pruned but instead place them in the "/assets" folder.

In DEV mode, the _vite.config.js_ settings will copy the non-fingerprinted files into "/priv/static".

For example, you have non-fingerprinted assets such as "robots.txt" and "sitemap.xml". You place them in "/assets/seo" and these files will by copied in the "priv/static" folder and will be served by Phoenix.
All your icons, eg favicons, should be placed in the folder "assets/icons" and will be copied in "priv/static/icons", and served by Phoenix.
You can safely do:

```elixir
# root.html.heex
<link rel="icon" href="icons/favicon.ico" type="image/png" sizes="48x48" />
```

when  `static_paths/0` is defined as:

```elixir
def static_paths, do: ~w(
      assets
      icons
      robots.txt
      sitemap.xml)
```

>[!IMPORTANT]
The other - fingerprinted - static assets should use the Elixir module `Vite.path/1`.

In DEV mode, it will prepend _http://localhost:5173_ to the file name and these assets are located in the folder "/assets/[...]".

For example, set `src={Vite.path("js/app.js")}` so `Vite` will serve it at _http://localhost:5173/js/app.js_.

Another example; suppose you have a Phoenix.Component named _techs.ex_ where you display some images, thus fingerprinted assets:

```elixir
<img src={Vite.path("images/my.svg"} alt="an-svg" loading="lazy" />
```

These images are placed in the folder "assets/images" and are fingerprinted.
In DEV mode, `Vite` will serve them as the `src` is now _http://localhost:5173/iamges/my.svg_.

In PROD mode, these "app.js" or "my.svg" files will have a hashed name. You therefor needed to find them.
The `Vite.path/1` does just this by looking into the _.vite/manifest.json_ file generated by `Vite`.
At compile time, it will bundle the files with the correct fingerprinted name and files will be placed in "/priv/static/assets" so `Phoenix` will serve them.

Note that this also means you do not need mix phx.digest anymore in the build stage.


- [Phoenix dev.exs config](#phoenix-devexs-config)
- [Root layout](#root-layout)
- [Vite Config: server and build options](#vite-config-server-and-build-options)
  - [Build options](#build-options)
  - [Server options](#server-options)
  - [Run a separate Vite dev server in DEBUG mode](#run-a-separate-vite-dev-server-in-debug-mode)
- [Package.json](#packagejson)
  - [Using workspace with pnpm](#using-workspace-with-pnpm)
  - [without workspace](#without-workspace)
- [Tailwind, daisyui and heroicons](#tailwind-daisyui-and-heroicons)
- [An Elixir file path resolving module](#an-elixir-file-path-resolving-module)
- [Vite.config.js](#viteconfigjs)
- [Dockerfile](#dockerfile)



## Phoenix dev.exs config


Define a config "env" variable:

```elixir
# config.exs

config :my_app, :env, config_env()
```

```elixir
# dev.exs

config :my_app, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  [...],
  code_reloader: true,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"lib/ex_vite_web/(controllers|live|components|channels)/.*(ex|heex)$",
      ~r"lib/ex_vite/.*(ex)$"
    ]
  ],
  watchers: [
    pnpm: [
      "vite",
      "serve",
      "--mode",
      "development",
      "--config",
      "vite.config.js",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]
```

## Root layout

Pass the assign `@env` in the LiveView (or controller) or use `Application.get_env(:ex_streams, :env)`

```elixir
|> assign(:env, Application.fetch_env!(:my_app, :env))
```


Add the following to "root.html.heex":

```elixir
# root.html.heex

<link
 :if={Application.get_env(:ex_vite, :env) === :prod}
 rel="stylesheet"
 href={Vite.path("css/app.css")}
/>

<script 
  :if={Application.get_env(:ex_vite, :env) === :dev}
  type="module"
  src="http://localhost:5173/@vite/client"
>
</script>

<script
 defer
 type="module"
 src={Vite.path("js/app.js")}
>
</script>
```

When you run the app, you can inspect the "network" tab and should get (at least) the two WebSocket connections: 

```
ws://localhost:4000/phoenix/live_reload/socket/websocket?vsn=2.0.0
ws://localhost:5173/?token=yFGCVgkhJxQg
```
 and

```
app.css -> http://localhost:5173/css/app.css
app.js  -> http://localhost:5173/js/app.js
```

## Vite Config, server and build options

### Build options

```js
const staticDir = "../priv/static";

const buildOps = (mode) => ({
  target: ["esnext"],
  // the directory to nest generated assets under (relative to build.outDir)
  outDir: staticDir,
  cssMinify: mode === 'production' && "lightningcss", // Use lightningcss for CSS minification
  rollupOptions: {
    input: mode == "production" ? getEntryPoints() : ["./js/app.js"],
    output: mode === "production" && {
      assetFileNames: "assets/[name]-[hash][extname]",
      chunkFileNames: "assets/[name]-[hash].js",
      entryFileNames: "assets/[name]-[hash].js",
    },
  },
  // generate a manifest file that contains a mapping
  // of non-hashed asset filenames in PROD mode
  manifest: mode === "production",
  path: ".vite/manifest.json",
  minify: mode === "production",
  emptyOutDir: true, // Remove old assets
  sourcemap: mode === "development" ? "inline" : true,
  reportCompressedSize: true,
  assetsInlineLimit: 0,
});
```

In PROD mode, the `getEntryPoints()` function is used to list of all your files that will be fingerprinted.

Also in PROD mode, the other static assets (non-fingerprinted) should by copied with the plugin `viteStaticCopy` to which we pass a list of objects (source, destination). These are eg SEO files (robots.txt, sitemap.xml), and your icons, fonts ...

In DEV mode, we will let Phoenix serve these non fingerprinted assets. We therefor need to copy them to "/priv/static" (remember this folder is cleared on each build). This is done withe a helper in __vite.config.js__.

### Server options

```js
// vite.config.js

const devServer = {
  cors: { origin: "http://localhost:4000" },
  allowedHosts: ["localhost"],
  strictPort: true,
  origin: "http://localhost:5173", // Vite dev server origin
  port: 5173, // Vite dev server port
  host: "localhost", // Vite dev server host
};
```

The __vite.config.js__ module will export:

```js
export default defineConfig = ({command, mode}) => {
  if (command == 'serve') {
    process.stdin.on('close', () => process.exit(0));
    copyStaticAssetsDev();
    process.stdin.resume();
  }

  return {
     server: mode === 'development' && devServer,
     build: buildOps(mode),
     publicDir: false,
     plugins: [tailwindcss(), viteCopy],
     [...]
  }
})
```

### Run a separate Vite dev server in DEBUG mode

You can also run the dev server in a separate terminal in DEBUG mode.

In this case, remove the watcher above, and run:

```sh
DEBUG=vite:* pnpm vite serve
```

The `DEBUG=vite:*` option gives extra informations that can be useful even if it may seem verbose.

## Package.json 

### Using workspace with pnpm

You can use `pnpm` with workspaces. In the root folder, define a "pnpm-workspace.yaml" file (❗️not "yml") and reference your "assets" folder and the "deps" folder (for `Phoenix.js`):

```yaml
# /pnpm-workspace.yaml

packages:
  - assets
  - deps/phoenix
  - deps/phoenix_html
  - deps/phoenix_live_view

ignoreBuildDependencies:
  - esbuild

onlyBuiltDependencies:
  - '@tailwindcss/oxide'
```

In the "assets" folder, run:

```
/assets> pnpm init
```

and populate your newly created package.json with your favourite client dependencies:

```sh
/assets> pnpm add -D tailwindcss @tailwindcss/vite daisyui vite-plugin-static-copy fast-glob lightningcss
```

▶️ Set "type": "module"
▶️ Set "name": "assets"
▶️ use "workspace" to reference Phoenix dependencies

```json
# /assets/package.json

{
  "type": "module",
  "name": "assets",
  "dependencies": {
    "phoenix": "workspace:*",
    "phoenix_html": "workspace:*",
    "phoenix_live_view": "workspace:*",
    "topbar": "^3.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.1.11",
    "daisyui": "^5.0.43",
    "tailwindcss": "^4.1.11",
    "vite": "^7.0.0",
    "vite-plugin-static-copy": "^2.3.1",
    "fast-glob": "^3.3.3",
    "lightningcss": "^1.30.1"
  }
}
```

In the root folder, install everything with:

```
/> pnpm install
```

### without workspace

Alternatively, if you don't use workspace, then reference directly the relative location for the Phoenix dependencies.

```json
{
  "type": "module",
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view",
  }
  ...
}
```

## Tailwind, daisyui and heroicons

▶️ __cf `Phoenix 1.8`__: disable automatic source detection and instead specify sources explicitely.

```css
# /assets/css/app.css

@import 'tailwindcss' source(none);

@source "../css";
@source "../**/.*{js, jsx}";
@source "../../lib/my_app_web/";

@plugin "daisyui";

@plugin "../vendor/heroicons.js";
```

where the "assets/vendor/heroicons.js" file is (from `phoenix` 1.8):

-------- heroicons.js --------

```js
// /assets/vendor/heroicons.js

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = plugin(function ({ matchComponents, theme }) {
  const iconsDir = path.join(__dirname, "../../deps/heroicons/optimized");
  const values = {};
  const icons = [
    ["", "/24/outline"],
    ["-solid", "/24/solid"],
    ["-mini", "/20/solid"],
    ["-micro", "/16/solid"],
  ];
  icons.forEach(([suffix, dir]) => {
    fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
      const name = path.basename(file, ".svg") + suffix;
      values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
    });
  });
  matchComponents(
    {
      hero: ({ name, fullPath }) => {
        let content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, "");
        content = encodeURIComponent(content);
        let size = theme("spacing.6");
        if (name.endsWith("-mini")) {
          size = theme("spacing.5");
        } else if (name.endsWith("-micro")) {
          size = theme("spacing.4");
        }
        return {
          [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
          "-webkit-mask": `var(--hero-${name})`,
          mask: `var(--hero-${name})`,
          "mask-repeat": "no-repeat",
          "background-color": "currentColor",
          "vertical-align": "middle",
          display: "inline-block",
          width: size,
          height: size,
        };
      },
    },
    { values }
  );
});
```

## An Elixir file path resolving module

This is needed to resolve the file path in dev or in prod mode.

❗️You need to change your application name in this module


-------- Vite.ex --------

```elixir
# lib/my_app_web/vite.ex

defmodule Vite do
  @moduledoc """
  Helper for Vite asset paths in development and production.
  """

  def path(asset) do
    case Application.get_env(:ex_streams, :env) do
      :dev -> "http://localhost:5173/" <> asset
      _ -> get_production_path(asset)
    end
  end

  defp get_production_path(asset) do
    manifest = get_manifest()

    case Path.extname(asset) do
      ".css" -> get_main_css_in(manifest)
      _ -> get_asset_path(manifest, asset)
    end
  end

  defp get_manifest do
    manifest_path = Path.join(:code.priv_dir(:ex_streams), "static/.vite/manifest.json")

    with {:ok, content} <- File.read(manifest_path),
        {:ok, decoded} <- Jason.decode(content) do
      decoded
    else
      _ -> raise "Could not read Vite manifest at #{manifest_path}"
    end
  end

  defp get_main_css_in(manifest) do
    manifest
    |> Enum.flat_map(fn {_key, entry} -> Map.get(entry, "css", []) end)
    |> Enum.find(&String.contains?(&1, "app"))
    |> case do
      nil -> raise "Main CSS file not found in manifest"
      file -> "/#{file}"
    end
  end

  defp get_asset_path(manifest, asset) do
    case manifest[asset] do
      %{"file" => file} -> "/#{file}"
      _ -> raise "Asset #{asset} not found in manifest"
    end
  end
end

```

## Vite.config.js

Your "vite.config.js" file is placed in the "assets" folder.

You locate all your assets in this "assets" folder, with a structure like:

`assets/{js, css, icons, images, wasm, fonts, seo}`

This `Vite` file will copy and build the necessary files for you (given the structure above):


-------- vite.config.js --------

```js
// /assets/vite.config.js

import { defineConfig } from "vite";
import fs from "fs"; // for file system operations
import path from "path";
import fg from "fast-glob"; // for recursive file scanning
import tailwindcss from "@tailwindcss/vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

const rootDir = path.resolve(import.meta.dirname);
const cssDir = path.resolve(rootDir, "css");
const jsDir = path.resolve(rootDir, "js");
const seoDir = path.resolve(rootDir, "seo");
const iconsDir = path.resolve(rootDir, "icons");
const srcImgDir = path.resolve(rootDir, "images");
const staticDir = path.resolve(rootDir, "../priv/static");

/* 
PROD mode: list of fingerprinted files to pass to RollUp(/Down)
*/
const getEntryPoints = () => {
  const entries = [];
  fg.sync([`${jsDir}/**/*.{js,jsx,ts,tsx}`]).forEach((file) => {
    if (/\.(js|jsx|ts|tsx)$/.test(file)) {
      entries.push(path.resolve(rootDir, file));
    }
  });

  fg.sync([`${srcImgDir}/**/*.*`]).forEach((file) => {
    if (/\.(jpg|png|svg|webp)$/.test(file)) {
      entries.push(path.resolve(rootDir, file));
    }
  });

  return entries;
};


const buildOps = (mode) => ({
  target: ["esnext"],
  outDir: staticDir,
  rollupOptions: {
    input:
      mode == "production" ? getEntryPoints() : ["./js/app.js"],
    // hash only in production mode
    output: mode === "production" && {
      assetFileNames: "assets/[name]-[hash][extname]",
      chunkFileNames: "assets/[name]-[hash].js",
      entryFileNames: "assets/[name]-[hash].js",
    },
  },
  manifest: mode === 'production',
  path: ".vite/manifest.json",
  minify: mode === "production",
  emptyOutDir: true, // Remove old assets
  sourcemap: mode === "development" ? "inline" : true,
});


/* 
Static assets served by Phoenix via the plugin `viteStaticCopy`
=> add other folders like assets/fonts...if needed
*/

// DEV mode: copy non fingerprinted from /assets to /priv/static
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

// PROD config for `viteStaticCopy`
const getBuildTargets = () => {
  const baseTargets = [];

  // Only add targets if source directories exist
  if (fs.existsSync(seoDir)) {
    baseTargets.push({
      src: path.resolve(seoDir, "**", "*"),
      dest: path.resolve(staticDir),
    });
  }

  if (fs.existsSync(iconsDir)) {
    baseTargets.push({
      src: path.resolve(iconsDir, "**", "*"),
      dest: path.resolve(staticDir, "icons"),
    });
  }

  const devManifestPath = path.resolve(staticDir, "manifest.webmanifest");
  if (fs.existsSync(devManifestPath)) {
    fs.writeFileSync(devManifestPath, JSON.stringify(manifestOpts, null, 2));
  };
  return baseTargets;
}; 

const resolveConfig = {
  alias: {
    "@": rootDir,
    "@js": jsDir,
    "@jsx": jsDir,
    "@css": cssDir,
    "@static": staticDir,
    "@assets": srcImgDir,
  },
  extensions: [".js", ".jsx", "png", ".css", "webp", "jpg", "svg"],
};

const devServer = {
  cors: { origin: "http://localhost:4000" },
  allowedHosts: ["localhost"],
  strictPort: true,
  origin: "http://localhost:5173", // Vite dev server origin
  port: 5173, // Vite dev server port
  host: "localhost", // Vite dev server host
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
    plugins: [
      viteStaticCopy({ targets: getBuildTargets() }),
      tailwindcss(),
    ],
    resolve: resolveConfig,
    // Disable default public dir (using Phoenix's)
    publicDir: false,
    build: buildOps(mode),
    server: mode === "development" && devServer,
  };
});
```


Notice that we took advantage of the resolver "@". In your code, you can do:

```js
import { myHook} from "@js/hooks/myHook";
```

## Dockerfile

To build for production, you will run `pnpm vite build`.
In the Dockerfile below, we use the "workspace" version:

-------- Dockerfile --------

```dockerfile
# Stage 1: Build
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.4
ARG DEBIAN_VERSION=bullseye-20250428-slim
ARG pnpm_VERSION=10.12.4


ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

ARG MIX_ENV=prod
ARG NODE_ENV=production

FROM ${BUILDER_IMAGE} AS builder


RUN apt-get update -y && apt-get install -y \
  build-essential  git curl && \
  curl -sL https://deb.nodesource.com/setup_22.x | bash - && \
  apt-get install -y nodejs && \
  apt-get clean && rm -f /var/lib/apt/lists/*_*

ARG MIX_ENV
ARG NODE_ENV
ENV MIX_ENV=${MIX_ENV}
ENV NODE_ENV=${NODE_ENV}

# Install pnpm
RUN corepack enable && corepack prepare pnpm@${pnpm_VERSION} --activate

# Prepare build dir
WORKDIR /app

# Install Elixir deps
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock pnpm-lock.yaml pnpm-workspace.yaml ./
RUN mix deps.get --only ${MIX_ENV}
RUN mkdir config

# compile Elxirr deps
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# compile Node deps
WORKDIR /app/assets
COPY assets/package.json  ./
WORKDIR /app
RUN pnpm install --frozen-lockfile

# Copy app server code before building the assets
# since the server code may contain Tailwind code.
COPY lib lib

# Copy, install & build assets--------
COPY priv priv

#  this will copy the assets/.env for the Maptiler api key loaded by Vite.loadenv
WORKDIR /app/assets
COPY assets ./ 
RUN pnpm vite build --mode ${NODE_ENV} --config vite.config.js

WORKDIR /app
# RUN mix phx.digest <-- used Vite to fingerprint assets instead
RUN mix compile

COPY config/runtime.exs config/

# Build the release-------
COPY rel rel
RUN mix release

# Stage 2: Runtime --------------------------------------------
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/liveview_pwa ./

# <-- needed for local testing
RUN chown -R nobody:nogroup /mnt
RUN mkdir -p /app/db && \
  chown -R nobody:nogroup /app/db && \
  chmod -R 777 /app/db && \
  chown nobody /app

USER nobody

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/server"]
```
