defmodule ExViteWeb.PageController do
  use ExViteWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    env = Application.fetch_env!(:ex_vite, :env)

    conn
    |> assign(:env, env)
    |> render(:home, layout: false)
  end
end
