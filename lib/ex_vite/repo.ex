defmodule ExVite.Repo do
  use Ecto.Repo,
    otp_app: :ex_vite,
    adapter: Ecto.Adapters.SQLite3
end
