# ExVite

- in "/", create `pnpm-workspace.yaml` (use "yaml", not "yml")
- in "/assets", `pnpm init` and set `"type": "module"`
- add packages with `pnpm add -D tailwindcss` or `pnpm remove tailwindcss` 
- go to "/" and run `pnpm install`.

## Settings with `Vite` dev server running on port 5174 and `Phoenix` server running on port 4001

- in __Vite.ex__, set `def path(asset), do: "http://localhost:5174/#{asset}"` for "dev" mode
- in __root.html.heex__, set the script src to:  `src="http://localhost:5174/@vite/client"`
- in __dev.exs__,  in the `Endpoint` config, set: `http: [ip: {127, 0, 0, 1}, port: 4001],`
- in __vite.config.js__, set the cors origin to `cors: { origin: "http://localhost:4001" },`  and `origin: "http://localhost:5174"` and `port: 5174`.

Run:

```sh
PORT=4001 iex -S mix phx.server
DEBUG=vite:* pnpm vite serve --mode development --config vite.config.js
```
