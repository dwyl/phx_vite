defmodule Mix.Tasks.Vite.Install do
  use Mix.Task
  import Mix.Generator

  @moduledoc """
  Installs and configures Vite for Phoenix LiveView projects.

  Sets up a complete Vite-based asset pipeline with Tailwind CSS, pnpm workspace,
  and generates helper modules for development and production asset handling.

  ## Usage

      $ mix vite.install
      $ mix vite.install --dep alpinejs --dev-dep postcss

  ## Options

    * `--dep` - Add a regular dependency (can be used multiple times)
    * `--dev-dep` - Add a development dependency (can be used multiple times)

  ## Examples

      $ mix vite.install --dep react --dep lodash
      $ mix vite.install --dev-dep sass --dev-dep autoprefixer

  """
  @shortdoc "Installs and configures Vite for Phoenix projects"

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
    # Note: Use hyphens in CLI arguments (--dev-dep), not underscores
    # (e.g., mix vite.install --dep topbar --dev-dep @types/node)
    {opts, _, _} =
      OptionParser.parse(args, switches: [dep: :keep, dev_dep: :keep], aliases: [d: :dep])

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

    # Setup pnpm workspace and install all dependencies
    setup_pnpm_workspace(extra_deps, extra_dev_deps)
    setup_install_deps()

    # Create asset directories and placeholder files
    setup_asset_directories()

    # Update static_paths to include icons
    update_static_paths(app_name)

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

    Mix.shell().info(
      "   • Asset directories: assets/icons/ and assets/seo/ with placeholder files"
    )

    Mix.shell().info("   • Updated static_paths in lib/#{app_name}_web.ex to include 'icons'")

    Mix.shell().info("   • Client libraries: #{Enum.join(extra_deps, ", ")}")
    Mix.shell().info("   • Dev dependencies: Tailwind CSS, Vite, DaisyUI, and build tools")
    Mix.shell().info("")
    Mix.shell().info("🚀 Next steps:")
    Mix.shell().info("   • Check 'static_paths/0' in your endpoint config")
    Mix.shell().info("   • Use 'Vite.path/1' in your code to define the source of your assets")
    Mix.shell().info("   • Run 'mix phx.server' to start your Phoenix server")
    Mix.shell().info("   • Vite dev server will start automatically on http://localhost:5173")
  end

  defp context() do
    # Get application name from mix.exs
    app_name = Mix.Project.config()[:app]
    app_module = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()

    %{
      app_name: app_name,
      app_module: app_module,
      web_module: "#{app_module}Web"
    }
  end

  defp setup_pnpm_workspace(extra_deps, extra_dev_deps) do
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

    # Build dependencies object for package.json
    base_deps = %{
      "phoenix" => "workspace:*",
      "phoenix_html" => "workspace:*",
      "phoenix_live_view" => "workspace:*"
    }

    # Add extra dependencies
    deps_map =
      Enum.reduce(extra_deps, base_deps, fn dep, acc ->
        Map.put(acc, dep, "latest")
      end)

    # Build dev dependencies
    base_dev_dependencies = [
      "@tailwindcss/oxide",
      "@tailwindcss/vite",
      "@tailwindcss/forms",
      "@tailwindcss/typography",
      "daisyui",
      "fast-glob",
      "tailwindcss",
      "vite",
      "vite-plugin-static-copy"
    ]

    all_dev_deps = base_dev_dependencies ++ extra_dev_deps

    dev_deps_map =
      Enum.reduce(all_dev_deps, %{}, fn dep, acc ->
        Map.put(acc, dep, "latest")
      end)

    # Create package.json with all dependencies
    package_json = %{
      "type" => "module",
      "dependencies" => deps_map,
      "devDependencies" => dev_deps_map,
      "packageManager" => "pnpm@#{version}"
    }

    File.write!("./pnpm-workspace.yaml", workspace_content)
    File.write!("./assets/package.json", Jason.encode!(package_json, pretty: true))

    {:ok, _} = File.rm_rf("./assets/node_modules")
    {:ok, _} = File.rm_rf("./node_modules")

    Mix.shell().info("Dependencies to install: #{length(extra_deps)} packages")
    Mix.shell().info("Dev dependencies to install: #{length(all_dev_deps)} packages")
  end

  defp setup_install_deps() do
    Mix.shell().info("Installing all dependencies with pnpm...")

    case System.cmd("pnpm", ["install"]) do
      {output, 0} ->
        Mix.shell().info("Assets installed successfully")
        Mix.shell().info(output)

      {error_output, _exit_code} ->
        Mix.shell().error("Failed to install assets: #{error_output}")
    end
  end

  defp setup_asset_directories() do
    # Create icons directory and copy favicon.ico from templates
    File.mkdir_p!("./assets/icons")
    favicon_source = Path.join([__DIR__, "templates", "favicon.ico"])
    File.cp!(favicon_source, "./assets/icons/favicon.ico")
    Mix.shell().info("Created assets/icons/ directory with favicon.ico")

    # Create SEO directory and copy robots.txt from templates, create empty sitemap.xml
    File.mkdir_p!("./assets/seo")
    robots_source = Path.join([__DIR__, "templates", "robots.txt"])
    File.cp!(robots_source, "./assets/seo/robots.txt")
    File.write!("./assets/seo/sitemap.xml", "")
    Mix.shell().info("Created assets/seo/ directory with robots.txt and sitemap.xml")
  end

  # Template functions using EEx
  defp vite_helper_template(assigns) do
    read_template("vite_helper.ex.eex")
    |> EEx.eval_string(assigns: assigns)
  end

  defp vite_watcher_template(assigns) do
    ("\n\n" <> read_template("vite_watcher.exs.eex"))
    |> EEx.eval_string(assigns: assigns)
  end

  defp config_template(assigns) do
    ("\n\n" <> read_template("config.exs.eex"))
    |> EEx.eval_string(assigns: assigns)
  end

  defp root_layout_template(assigns) do
    read_template("root_layout.html.eex")
    |> EEx.eval_string(assigns: assigns)
  end

  defp vite_config_template() do
    read_template("vite.config.js")
  end

  defp read_template(filename) do
    template_path = Path.join([__DIR__, "templates", filename])
    File.read!(template_path)
  end

  defp update_static_paths(app_name) do
    web_file_path = "lib/#{app_name}_web.ex"

    content = File.read!(web_file_path)

    if String.contains?(content, "icons") do
      Mix.shell().info("#{web_file_path} already includes 'icons' in static_paths")
    else
      updated_content = String.replace(content, ~r/~w\(/, "~w(icons ")

      if updated_content != content do
        File.write!(web_file_path, updated_content)
        Mix.shell().info("Updated #{web_file_path} to include 'icons' in static_paths")
      end
    end
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
