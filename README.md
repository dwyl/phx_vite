# ExVite

[TODO] a mix task?

## Setup

- in "/", create `pnpm-workspace.yaml` (use "yaml", not "yml")
- go to "/assets", run `pnpm init` and set `"type": "module"`
- add/remove packages with `pnpm add -D xxx` or `pnpm remove xxx`
- go to "/" and run `pnpm install`.

## Settings with `Vite` dev server running on port 5173 and `Phoenix` server running on port 4000

- in __Vite.ex__, 
  - set `def path(asset), do: "http://localhost:5173/#{asset}"` for "dev" mode,
  - set your __app_name__,
- in __root.html.heex__, set the script src to:  `src="http://localhost:5173/@vite/client"`
- in __dev.exs__,  in the `Endpoint` config, set: `http: [ip: {127, 0, 0, 1}, port: 4000],`
- in __vite.config.js__, set the cors origin to `cors: { origin: "http://localhost:4000" },`  and `origin: "http://localhost:5173"` and `port: 5173`.

Run:

```sh
PORT=4000 iex -S mix phx.server
DEBUG=vite:* pnpm vite serve --mode development --config vite.config.js
```

A more detailed blog: <https://dev.to/ndrean/phoenix-vite-dev-setup-195i>
