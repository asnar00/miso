# navigation and history
*deep-link via URL with back/forward*

Each snippet selection maps to a shareable URL (hash or query parameter).

Behavior

- Update the URL on navigation; browser Back/Forward restores prior selection
- Copy Link action copies the current deep-link
- On load, parse the URL and open the referenced snippet; fallback to home

Stability

- Use canonical spec paths (e.g., `tools/hello`) to form the link target


