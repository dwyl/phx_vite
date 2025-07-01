if Application.compile_env!(:ex_vite, :env) == :dev do
  defmodule Vite do
    @moduledoc """
    A helper module to manage Vite file discovery.

    In dev mode, it appends "http://localhost:5173" so that Phoenix will proxy static assets requests to the Vite server.

    In prod mode, it finds the fingerprinted name from the .vite/manifest.json dictionary.
    """
    def path(asset) do
      "http://localhost:5174/#{asset}"
    end
  end
else
  defmodule Vite do
    require Logger

    # Ensure the manifest is loaded at compile time in production
    def path(asset) do
      app_name = :ex_vite
      manifest = get_manifest(app_name)

      case Path.extname(asset) do
        ".css" ->
          get_main_css_in(manifest)

        _ ->
          get_name_in(manifest, asset)
      end
    end

    defp get_manifest(app_name) do
      manifest_path =
        Path.join(:code.priv_dir(app_name), "static/.vite/manifest.json")

      with {:ok, content} <- File.read(manifest_path),
           {:ok, decoded} <- Jason.decode(content) do
        decoded
      else
        _ -> raise "Could not read or decode Vite manifest at #{manifest_path}"
      end
    end

    def get_main_css_in(manifest) do
      manifest
      |> Enum.flat_map(fn {_key, entry} ->
        Map.get(entry, "css", [])
      end)
      |> Enum.filter(fn file -> String.contains?(file, "app") end)
      |> List.first()
    end

    def get_name_in(manifest, asset) do
      case manifest[asset] do
        %{"file" => file} -> "/#{file}"
        _ -> raise "Asset #{asset} not found in manifest"
      end
    end
  end
end
