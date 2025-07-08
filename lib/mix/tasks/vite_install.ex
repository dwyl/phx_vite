defmodule Mix.Tasks.Vite.Install do
  use Mix.Task
  import Mix.Generator

  def context() do
    # Get application name from mix.exs
    app_name = Mix.Project.config()[:app]
    app_module = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()

    %{
      app_name: app_name,
      app_module: app_module,
      web_module: "#{app_module}Web"
    }
  end

  @impl Mix.Task
  def run(args) do
    case System.find_executable("pnpm") do
      nil ->
        Mix.shell().error("pnpm is not installed. Please install pnpm to continue.")
        Mix.raise("Missing dependency: pnpm")

      _ ->
        :ok
    end

    # Parse command line arguments. :keep allows multiple values
    # (e.g., mix assets.install --dep topbar --dep react)
    {opts, _, _} = OptionParser.parse(args, switches: [dep: :keep, dev_dep: :keep])

    extra_deps = Keyword.get_values(opts, :dep)
    extra_dev_deps = Keyword.get_values(opts, :dev_dep)

    %{app_name: app_name, app_module: app_module} = context()

    Mix.shell().info("Assets setup started for #{app_name} (#{app_module})...")

    Mix.shell().info("Extra dependencies to install: #{Enum.join(extra_deps, ", ")}")

    if extra_dev_deps != [] do
      Mix.shell().info("Extra dev dependencies to install: #{Enum.join(extra_dev_deps, ", ")}")
    end

    # Add topbar by default unless --no-topbar is specified
    extra_deps = extra_deps ++ ["topbar"]

    # Setup pnpm workspace and dependencies
    setup_pnpm_workspace(extra_deps)
    setup_dev_dependencies(extra_dev_deps)
    setup_install_deps()

    # Add config first before generating files that depend on it
    append_to_file("config/config.exs", config_template(context()))

    create_file("lib/#{app_name}_web/vite.ex", vite_helper_template(context()))

    create_file(
      "lib/#{app_name}_web/components/layouts/root.html.heex",
      root_layout_template(context())
    )

    create_file("assets/vite.config.js", vite_config_template())

    append_to_file("config/dev.exs", vite_watcher_template(context()))

    Mix.shell().info("Assets installation completed!")
    Mix.shell().info("")
    Mix.shell().info("✅ What was added to your project:")
    Mix.shell().info("   • Environment config in config/config.exs")
    Mix.shell().info("   • Vite watcher configuration in config/dev.exs")
    Mix.shell().info("   • Vite configuration file at assets/vite.config.js")

    Mix.shell().info(
      "   • Updated root layout template at lib/#{app_name}_web/components/layouts/root.html.heex"
    )

    Mix.shell().info("   • Vite helper module at lib/#{app_name}_web/vite.ex")
    Mix.shell().info("   • pnpm workspace configuration at pnpm-workspace.yaml")
    Mix.shell().info("   • Package.json with Phoenix workspace dependencies")
    Mix.shell().info("   • Client libraries: #{Enum.join(extra_deps, ", ")}")
    Mix.shell().info("   • Dev dependencies: Tailwind CSS, Vite, DaisyUI, and build tools")
    Mix.shell().info("")
    Mix.shell().info("🚀 Next steps:")
    Mix.shell().info("   • Check static_paths/0 which defines the static assets served by Phoenix")
    Mix.shell().info("   • Set up app.css in the assets/css/ directory")
    Mix.shell().info("   • Run 'mix phx.server' to start your Phoenix server")
    Mix.shell().info("   • Vite dev server will start automatically on http://localhost:5173")
    Mix.shell().info("   • Edit assets in the assets/ directory with live reload support")
  end

  defp setup_pnpm_workspace(extra_deps) do
    {v, _} = System.cmd("pnpm", ["-v"])
    version = String.trim(v)

    workspace_content = """
    packages:
      - assets
      - deps/phoenix
      - deps/phoenix_html
      - deps/phoenix_live_view

    ignoredBuiltDependencies:
      - esbuild

    onlyBuiltDependencies:
      - '@tailwindcss/oxide'
    """

    package_json_content =
      """
      {
        "type": "module",
        "dependencies": {
          "phoenix": "workspace:*",
          "phoenix_html": "workspace:*",
          "phoenix_live_view": "workspace:*"
        },
        "packageManager": "pnpm@#{version}"
      }
      """

    File.write!("./pnpm-workspace.yaml", workspace_content)
    File.write!("./assets/package.json", package_json_content)

    {:ok, _} = File.rm_rf("./assets/node_modules")
    {:ok, _} = File.rm_rf("./node_modules")

    # Install dependencies if any were specified
    {_output, 0} = System.cmd("pnpm", ["add", "--prefix", "assets"] ++ extra_deps)
    Mix.shell().info("Dependencies installed: #{length(extra_deps)} packages")
  end

  defp setup_dev_dependencies(extra_dev_deps) do
    base_dev_dependencies = ~w(
      @tailwindcss/oxide
      @tailwindcss/vite
      @tailwindcss/forms
      @tailwindcss/typography
      daisyui
      fast-glob
      tailwindcss
      vite
      vite-plugin-static-copy
    )

    dev_dependencies = base_dev_dependencies ++ extra_dev_deps

    {_output, 0} = System.cmd("pnpm", ["add", "--prefix", "assets", "-D"] ++ dev_dependencies)
    Mix.shell().info("Dev dependencies installed: #{length(dev_dependencies)} packages")
  end

  defp setup_install_deps() do
    case System.cmd("pnpm", ["install"]) do
      {_output, 0} ->
        Mix.shell().info("Assets installed successfully")

      {error_output, _exit_code} ->
        Mix.shell().error("Failed to install assets: #{error_output}")
    end
  end

  # Template functions using EEx
  defp vite_helper_template(assigns) do
    """
    defmodule Vite do
      @moduledoc \"\"\"
      Helper for Vite asset paths in development and production.
      \"\"\"

      def path(asset) do
        case Application.get_env(:<%= @app_name %>, :env) do
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
        manifest_path = Path.join(:code.priv_dir(:<%= @app_name %>), "static/.vite/manifest.json")

        with {:ok, content} <- File.read(manifest_path),
            {:ok, decoded} <- Jason.decode(content) do
          decoded
        else
          _ -> raise "Could not read Vite manifest at \#{manifest_path}"
        end
      end

      defp get_main_css_in(manifest) do
        manifest
        |> Enum.flat_map(fn {_key, entry} -> Map.get(entry, "css", []) end)
        |> Enum.find(&String.contains?(&1, "app"))
        |> case do
          nil -> raise "Main CSS file not found in manifest"
          file -> "/\#{file}"
        end
      end

      defp get_asset_path(manifest, asset) do
        case manifest[asset] do
          %{"file" => file} -> "/\#{file}"
          _ -> raise "Asset \#{asset} not found in manifest"
        end
      end
    end
    """
    |> EEx.eval_string(assigns: assigns)
  end

  defp vite_watcher_template(assigns) do
    """

    # Vite watcher configuration added by mix assets.install
    config :<%= @app_name %>, <%= @web_module %>.Endpoint,
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
    """
    |> EEx.eval_string(assigns: assigns)
  end

  defp config_template(assigns) do
    """

    # Environment configuration added by mix assets.install
    config :<%= @app_name %>, :env, config_env()
    """
    |> EEx.eval_string(assigns: assigns)
  end

  defp root_layout_template(assigns) do
    """
    <!DOCTYPE html>
    <html lang="en" class="[scrollbar-gutter:stable]">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title default="<%= @app_module %>" suffix=" · Phoenix Framework">
          {assigns[:page_title]}
        </.live_title>

        <link :if={Application.get_env(:<%= @app_name %>, :env) == :prod} rel="stylesheet" href={Vite.path("css/app.css")} />

        <script :if={Application.get_env(:<%= @app_name %>, :env) == :dev} type="module" src="http://localhost:5173/@vite/client"></script>

        <script defer type="module" src={Vite.path("js/app.js")}></script>
      </head>
      <body class="bg-white">
        {@inner_content}
      </body>
    </html>
    """
    |> EEx.eval_string(assigns: assigns)
  end

  defp vite_config_template() do
    """
    import { defineConfig } from "vite";
    import tailwindcss from "@tailwindcss/vite";
    import path from "path";
    import fs from "fs";
    import fg from "fast-glob";
    import { viteStaticCopy } from "vite-plugin-static-copy";

    const rootDir = path.resolve(import.meta.dirname);
    const staticDir = path.resolve(rootDir, "../priv/static");

    const jsDir = path.resolve(rootDir, "js");
    const srcImgDir = path.resolve(rootDir, "images");

    const seoDir = path.resolve(rootDir, "seo");
    const iconsDir = path.resolve(rootDir, "icons");

    function getEntryPoints() {
      const entries = [];
      fg.sync([`${jsDir}/**/*.{js,jsx,ts,tsx}`]).forEach((file) => {
        if (/\\.(js|jsx|ts|tsx)$/.test(file)) {
          entries.push(path.resolve(rootDir, file));
        }
      });

      fg.sync([`${srcImgDir}/**/*.*`]).forEach((file) => {
        if (/\\.(jpe?g|png|svg|webp)$/.test(file)) {
          entries.push(path.resolve(rootDir, file));
        }
      });

      return entries;
    }

    const buildOps = (mode) => ({
      target: ["esnext"],
      // Specify the directory to nest generated assets under (relative to build.outDir
      outDir: staticDir,
      cssCodeSplit: mode === "production", // Split CSS for better caching
      // cssMinify: mode === "production" && "lightningcss", // Use lightningcss for CSS minification
      rollupOptions: {
        input: mode === "production" ? getEntryPoints() : ["./js/app.js"],
        output: mode === "production" && {
          assetFileNames: "assets/[name]-[hash][extname]",
          chunkFileNames: "assets/[name]-[hash].js",
          entryFileNames: "assets/[name]-[hash].js",
        },
      },
      // generate a manifest file that contains a mapping of non-hashed asset filenames
      // to their hashed versions, which can then be used by a server framework
      // to render the correct asset links.
      manifest: mode === "production",
      path: ".vite/manifest.json",
      minify: mode === "production",
      emptyOutDir: true, // Remove old assets
      // sourcemap: mode === "development" ? "inline" : true,
      reportCompressedSize: true,
      assetsInlineLimit: 0,
    });

    const devServer = {
      cors: { origin: "http://localhost:4000" },
      allowedHosts: ["localhost"],
      strictPort: true,
      origin: "http://localhost:5173", // Vite dev server origin
      port: 5173, // Vite dev server port
      host: "localhost", // Vite dev server host
      // watch: {
      //   ignored: ["**/priv/static/**", "**/lib/**", "**/*.ex", "**/*.exs"],
      // },
    };

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

      // if (fs.existsSync(wasmDir)) {
      //   baseTargets.push({
      //     src: path.resolve(wasmDir, "**", "*.wasm"),
      //     dest: path.resolve(staticDir, "wasm"),
      //   });
      // }

      const devManifestPath = path.resolve(staticDir, "manifest.webmanifest");
      if (fs.existsSync(devManifestPath)) {
        //   baseTargets.push({
        //     src: devManifestPath,
        //     dest: staticDir,
        //   });
        fs.writeFileSync(devManifestPath, JSON.stringify(manifestOpts, null, 2));
      }

      return baseTargets;
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
          tailwindcss(),
          // mode === "production"
          viteStaticCopy({ targets: getBuildTargets() }),
          // : null,
        ],
        server: mode === "development" && devServer,
        build: buildOps(mode),
        publicDir: false,
      };
    });
    """
  end

  defp append_to_file(path, content) do
    existing_content = File.read!(path)

    # Extract just the config line to check for (remove comments)
    config_line =
      content
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "config :"))

    # Check if the specific config already exists
    if config_line && String.contains?(existing_content, String.trim(config_line)) do
      Mix.shell().info("#{path} already contains the configuration, skipping...")
    else
      case File.write(path, content, [:append]) do
        :ok -> Mix.shell().info("Updated #{path}")
        {:error, reason} -> Mix.shell().error("Failed to update #{path}: #{reason}")
      end
    end
  end
end

