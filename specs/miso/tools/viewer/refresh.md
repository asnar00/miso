# refresh
*auto-refresh on change (native: watch; web: websocket)*

Keep the view in sync with spec changes automatically.

Modes

- Native (desktop): watch the `specs/` directory using filesystem events; debounce 200ms
- Web: subscribe to a WebSocket that publishes spec change events; fallback to polling every 2s if unavailable

Behavior

- On change of any included file for the current snippet, re-render markdown and children list
- Preserve scroll position and selection when possible


