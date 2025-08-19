#!/usr/bin/env python3
"""
Minimal miso build tool

Reads a tool spec markdown (prose-first) and scaffolds an implementation in the code/ tree.
This is a pragmatic, good-first version implementing the conventions defined under
specs/miso/tools/build/*.md without requiring frontmatter.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


BUILD_TOOL_VERSION = "0.1.0"


@dataclass
class SpecSummary:
    spec_path: Path
    tool_id: str
    title: str
    summary: str
    suggested_output_line: Optional[str]


def read_file_text(file_path: Path) -> str:
    return file_path.read_text(encoding="utf-8")


def extract_title_and_summary(markdown_text: str) -> tuple[str, str]:
    lines = [line.rstrip("\n") for line in markdown_text.splitlines()]
    title = ""
    summary = ""
    for idx, line in enumerate(lines[:5]):  # title/summary should be at the top
        if not title and line.startswith("# "):
            title = line[2:].strip()
            continue
        if title and not summary and line.strip().startswith("*") and line.strip().endswith("*"):
            summary = line.strip().strip("*").strip()
            break
    if not title:
        title = "unknown"
    if not summary:
        summary = "no summary"
    return title, summary


def extract_example_output(markdown_text: str) -> Optional[str]:
    """Heuristics: look for a simple usage block where a line with ">hello" (or similar)
    is followed by a line that looks like output. Fallback to a literal 'hello world!' if present.
    """
    lines = [line.rstrip("\n") for line in markdown_text.splitlines()]
    # Prefer any explicit 'hello world!' anywhere
    for line in lines:
        if "hello world!" in line.lower():
            # pull the exact casing from the line if possible
            match = re.search(r"hello world!", line)
            return match.group(0) if match else "hello world!"

    # Look for a block beginning with a command (e.g., >hello)
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(">hello") or stripped == "hello":
            if i + 1 < len(lines):
                candidate = lines[i + 1].strip().lstrip(">").strip()
                if candidate:
                    return candidate
    return None


def get_git_commit_sha() -> Optional[str]:
    try:
        result = subprocess.run([
            "git",
            "rev-parse",
            "HEAD",
        ], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except Exception:
        return None


def summarize_spec(spec_path: Path) -> SpecSummary:
    text = read_file_text(spec_path)
    title, summary = extract_title_and_summary(text)
    suggested_output_line = extract_example_output(text)
    # tool_id: specs/A/B/C.md -> A/B/C
    relative = spec_path.as_posix()
    if "/specs/" in relative:
        relative = relative.split("/specs/", 1)[1]
    tool_id = relative[:-3] if relative.endswith(".md") else relative
    return SpecSummary(
        spec_path=spec_path,
        tool_id=tool_id,
        title=title,
        summary=summary,
        suggested_output_line=suggested_output_line,
    )


def ensure_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_text_file(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def generate_manifest(
    dest_dir: Path,
    spec: SpecSummary,
    impl_key: str,
    template_name: str,
    context_included: list[str] | None = None,
    context_file_digests: dict[str, str] | None = None,
    context_overall_digest: str | None = None,
) -> None:
    manifest = {
        "spec_path": spec.spec_path.as_posix(),
        "spec_title": spec.title,
        "spec_summary": spec.summary,
        "spec_commit_sha": get_git_commit_sha(),
        "build_timestamp": datetime.now(timezone.utc).isoformat(),
        "build_tool_version": BUILD_TOOL_VERSION,
        "template_catalog_version": "builtin-0.1",
        "impl_key": impl_key,
        "template_name": template_name,
        "entrypoints": {
            "cli": "run" if impl_key == "sh" else "main.py",
            "library": "execute" if impl_key == "py" else None,
        },
        "context_files": {
            "manifest": "context_manifest.json",
            "bundle": "context_bundle.txt",
        },
        "context_digests": {
            "included": context_included or [],
            "file_sha256": context_file_digests or {},
            "overall_sha256": context_overall_digest or None,
        },
    }
    write_text_file(dest_dir / "manifest.json", json.dumps(manifest, indent=2) + "\n")


def generate_pseudocode(dest_dir: Path, spec: SpecSummary) -> None:
    pseudocode = (
        f"# {spec.title}\n"
        f"*auto-generated summary from spec*\n\n"
        f"- Summary: {spec.summary}\n"
        f"- Behavior: minimal implementation derived from example/output heuristics.\n"
    )
    write_text_file(dest_dir / "pseudocode.md", pseudocode)


def generate_python_impl(dest_dir: Path, spec: SpecSummary) -> None:
    ensure_directory(dest_dir)
    message = spec.suggested_output_line or spec.summary or spec.title
    py_code = f'''#!/usr/bin/env python3
import argparse


def execute() -> int:
    print({message!r})
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description={spec.title!r})
    _ = parser.parse_args()
    raise SystemExit(execute())


if __name__ == "__main__":
    main()
'''
    write_if_changed(dest_dir / "main.py", py_code)
    generate_pseudocode(dest_dir, spec)
    # Manifest is generated later once context is assembled


def generate_shell_impl(dest_dir: Path, spec: SpecSummary) -> None:
    ensure_directory(dest_dir)
    message = spec.suggested_output_line or spec.summary or spec.title
    sh_code = f'''#!/usr/bin/env sh
set -eu
echo {sh_quote(message)}
'''
    run_path = dest_dir / "run"
    write_if_changed(run_path, sh_code)
    os.chmod(run_path, 0o755)
    generate_pseudocode(dest_dir, spec)
    # Manifest is generated later once context is assembled


def sh_quote(text: str) -> str:
    # Simple POSIX shell quoting
    return "'" + text.replace("'", "'\\''") + "'"


def generate_web_impl(dest_dir: Path, spec: SpecSummary) -> None:
    ensure_directory(dest_dir)
    # Basic static scaffold following viewer specs choices (light theme, resizable pane)
    index_html = f'''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{spec.title} — viewer</title>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <div id="app" data-self-spec="specs/{spec.tool_id}.md">
      <aside id="pane" aria-label="Viewer pane">
        <div id="breadcrumbs"></div>
        <article id="markdown"></article>
        <div id="children"></div>
      </aside>
      <div id="handle" tabindex="0" aria-label="Resize"></div>
      <main id="main">Target application area</main>
    </div>
    <script src="app.js"></script>
  </body>
  </html>
'''
    styles_css = '''*{box-sizing:border-box}body{margin:0;font:14px/1.4 -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1f2328;background:#fff}#app{display:flex;min-height:100vh}#pane{width:280px;min-width:240px;max-width:480px;border-right:1px solid #d0d7de;padding:12px 12px 0 12px;overflow:auto}#handle{width:8px;cursor:col-resize;background:transparent}#handle:focus{outline:2px solid #0969da}#breadcrumbs{font-size:12px;color:#57606a;margin-bottom:8px}#markdown{padding-bottom:12px;border-bottom:1px solid #d0d7de}#children{padding-top:8px}#children .row{display:flex;gap:8px;padding:6px 4px;border-radius:6px;cursor:pointer}#children .row:hover{background:#f6f8fa}#children .title{font-weight:600}#children .summary{color:#57606a;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}pre,code{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}pre{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:8px;overflow:auto}table{border-collapse:collapse}th,td{border:1px solid #d0d7de;padding:4px 6px}#main{flex:1;padding:16px}
'''
    app_js = '''(function(){
  const app = document.getElementById('app');
  const pane = document.getElementById('pane');
  const handle = document.getElementById('handle');
  const mdEl = document.getElementById('markdown');
  const childrenEl = document.getElementById('children');
  const crumbsEl = document.getElementById('breadcrumbs');
  const selfSpec = app.getAttribute('data-self-spec');

  // Resize behavior
  let dragging = false; let startX = 0; let startW = 280;
  handle.addEventListener('mousedown', (e)=>{ dragging = true; startX = e.clientX; startW = pane.offsetWidth; document.body.style.userSelect='none'; });
  window.addEventListener('mouseup', ()=>{ dragging=false; document.body.style.userSelect=''; });
  window.addEventListener('mousemove', (e)=>{ if(!dragging) return; const dx = e.clientX - startX; let w = startW + dx; w = Math.max(240, Math.min(480, w)); pane.style.width = w + 'px'; });
  handle.addEventListener('dblclick', ()=>{ pane.style.width = '280px'; });
  handle.addEventListener('keydown', (e)=>{ if(e.key==='ArrowLeft'){ adjust(-16); } if(e.key==='ArrowRight'){ adjust(16); } if(e.shiftKey && e.key==='ArrowLeft'){ adjust(-32);} if(e.shiftKey && e.key==='ArrowRight'){ adjust(32);} function adjust(dx){ let w = pane.offsetWidth + dx; w = Math.max(240, Math.min(480,w)); pane.style.width = w + 'px'; }});

  // Very small Markdown renderer for headings/paragraphs/code fences
  function renderMarkdown(text){
    const esc = (s)=>s.replace(/[&<>]/g, c=>({"&":"&amp;","<":"&lt;",
      ">":"&gt;"}[c]));
    const lines = text.split(/\r?\n/);
    let out = [];
    let inCode = false; let codeBuf = [];
    for(const line of lines){
      if(line.startsWith('```')){ if(inCode){ out.push('<pre><code>'+esc(codeBuf.join('\n'))+'</code></pre>'); codeBuf=[]; inCode=false; } else { inCode=true; } continue; }
      if(inCode){ codeBuf.push(line); continue; }
      if(line.startsWith('# ')){ out.push('<h1>'+esc(line.slice(2).trim())+'</h1>'); continue; }
      if(line.startsWith('## ')){ out.push('<h2>'+esc(line.slice(3).trim())+'</h2>'); continue; }
      if(line.trim()===''){ out.push('<p></p>'); continue; }
      out.push('<p>'+esc(line)+'</p>');
    }
    return out.join('\n');
  }

  function parseBundle(text){
    const files = {}; let current = null; let buf = [];
    const beginRe = /^--- BEGIN (.+) ---$/; const endRe = /^--- END (.+) ---$/;
    for(const raw of text.split(/\r?\n/)){
      const m1 = raw.match(beginRe); const m2 = raw.match(endRe);
      if(m1){ current = m1[1]; buf=[]; continue; }
      if(m2){ if(current){ files[current]=buf.join('\n'); current=null; buf=[]; } continue; }
      if(current){ buf.push(raw); }
    }
    return files;
  }

  function updateBreadcrumbs(specPath){
    const path = specPath.replace(/^specs\//,'').replace(/\.md$/, '');
    const parts = path.split('/');
    let acc = [];
    crumbsEl.innerHTML = parts.map((p,i)=>{ acc.push(p); const id = acc.join('/'); return '<a href="#'+id+'">'+p+'</a>'; }).join(' \u203A ');
  }

  function renderChildren(files, specPath){
    const base = specPath.replace(/\.md$/,'');
    const folder = 'specs/'+base+'/';
    const children = Object.keys(files).filter(k=> k.startsWith(folder) && k!==specPath ).sort();
    if(children.length===0){ childrenEl.innerHTML = '<div style="color:#57606a">No child snippets yet.</div>'; return; }
    childrenEl.innerHTML = children.map(k=>{
      const title = (files[k].split(/\r?\n/).find(l=>l.startsWith('# '))||'# Untitled').slice(2);
      const sumLine = files[k].split(/\r?\n/).find(l=>/^\*.*\*$/.test(l.trim()));
      const summary = sumLine? sumLine.trim().replace(/^\*/,'').replace(/\*$/,'') : '';
      return '<div class="row" data-spec="'+k+'"><div class="title">'+title+'</div><div class="summary">'+summary+'</div></div>';
    }).join('');
    for(const row of childrenEl.querySelectorAll('.row')){
      row.addEventListener('click', ()=> navigate(row.getAttribute('data-spec')));
    }
  }

  function navigate(specPath){
    location.hash = '#'+specPath.replace(/^specs\//,'').replace(/\.md$/,'');
    load(specPath);
  }

  async function load(specPath){
    updateBreadcrumbs(specPath);
    const bundle = await fetch('context_bundle.txt').then(r=>r.text()).catch(()=> '');
    const files = parseBundle(bundle);
    let md = files[specPath];
    if(md == null){
      // Fallback: fetch the markdown directly from the server (absolute path from repo root)
      const url = specPath.startsWith('/') ? specPath : ('/' + specPath);
      try {
        md = await fetch(url).then(r=> r.ok ? r.text() : '# Missing\n');
      } catch(_e){
        md = '# Missing\n';
      }
    }
    mdEl.innerHTML = renderMarkdown(md);
    renderChildren(files, specPath);
  }

  // Initial: default to specs/miso.md if no deep-link hash is present
  const initial = (location.hash? 'specs/'+location.hash.slice(1)+'.md' : 'specs/miso.md');
  load(initial);
})();
'''
    write_if_changed(dest_dir / "index.html", index_html)
    write_if_changed(dest_dir / "styles.css", styles_css)
    write_if_changed(dest_dir / "app.js", app_js)
    generate_pseudocode(dest_dir, spec)
    # Manifest is generated later once context is assembled


def build(spec_path: Path, impl_key: str) -> Path:
    spec = summarize_spec(spec_path)
    dest_dir = Path("code") / spec.tool_id / impl_key
    # Pre-check: if up-to-date by context digest and versions, skip regeneration
    prev_manifest = load_manifest_if_exists(dest_dir)
    # Generate implementation files (idempotent writes avoided by write_if_changed)
    if impl_key == "py":
        generate_python_impl(dest_dir, spec)
    elif impl_key == "sh":
        generate_shell_impl(dest_dir, spec)
    elif impl_key == "web":
        generate_web_impl(dest_dir, spec)
    else:
        raise SystemExit(f"Unsupported --impl {impl_key!r}. Try one of: py, sh, web")
    # Assemble context files alongside implementation and compute digests
    ctx = assemble_and_write_context(dest_dir, spec.spec_path)
    # If previous manifest exists and digests match and tool/template versions match, mark as up-to-date
    if prev_manifest and is_up_to_date(prev_manifest, ctx):
        # Still ensure manifest reflects current timestamps if needed, but avoid rewriting identical content
        generate_manifest(
            dest_dir,
            spec,
            impl_key=impl_key,
            template_name=("builtin/web-viewer" if impl_key == "web" else "builtin/echo"),
            context_included=ctx["included"],
            context_file_digests=ctx["file_sha256"],
            context_overall_digest=ctx["overall_sha256"],
        )
        print("Up to date")
        return dest_dir
    # Otherwise, write manifest fresh
    generate_manifest(
        dest_dir,
        spec,
        impl_key=impl_key,
        template_name=("builtin/web-viewer" if impl_key == "web" else "builtin/echo"),
        context_included=ctx["included"],
        context_file_digests=ctx["file_sha256"],
        context_overall_digest=ctx["overall_sha256"],
    )
    return dest_dir


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="miso-build", description="Generate code from a miso tool spec")
    parser.add_argument("spec", type=str, help="Path to spec markdown, e.g., specs/tools/hello.md")
    parser.add_argument("--impl", type=str, required=True, help="Implementation key: py, sh, or web")
    parser.add_argument("--force", action="store_true", help="Force regeneration even if inputs unchanged")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv or sys.argv[1:])
    spec_path = Path(args.spec).resolve()
    if not spec_path.exists():
        raise SystemExit(f"Spec not found: {spec_path}")
    if args.force:
        # Remove prior manifest to force rebuild logic
        old_manifest = Path("code") / summarize_spec(spec_path).tool_id / args.impl / "manifest.json"
        if old_manifest.exists():
            try:
                old_manifest.unlink()
            except Exception:
                pass
    dest = build(spec_path, args.impl)
    print(f"Wrote {dest.as_posix()}")


 # -------------------- Context Assembly --------------------

def assemble_and_write_context(dest_dir: Path, spec_path: Path) -> dict[str, object]:
    """Create context_manifest.json and context_bundle.txt in dest_dir following
    the rules from specs/miso/tools/build/context-assembly.md.
    """
    repo_root = Path.cwd()
    spec_path = spec_path.resolve()
    try:
        spec_rel = spec_path.relative_to(repo_root).as_posix()
    except Exception:
        spec_rel = spec_path.as_posix()

    if "/specs/" in spec_rel:
        rel_after_specs = spec_rel.split("/specs/", 1)[1]
        specs_prefix = "specs"
    elif spec_rel.startswith("specs/"):
        rel_after_specs = spec_rel[len("specs/"):]
        specs_prefix = "specs"
    else:
        # Not under specs; nothing to assemble
        return {"included": [], "file_sha256": {}, "overall_sha256": None}

    # parts without .md
    if rel_after_specs.endswith(".md"):
        stem = rel_after_specs[:-3]
    else:
        stem = rel_after_specs
    parts = stem.split("/")

    # Ancestors (excluding self)
    ancestors: list[str] = []
    for i in range(1, len(parts)):
        candidate = f"{specs_prefix}/" + "/".join(parts[:i]) + ".md"
        ancestors.append(candidate)

    # Self
    self_path = f"{specs_prefix}/" + rel_after_specs

    # Descendants under folder specs/A/B/C/
    descendants_dir = Path(specs_prefix) / "/".join(parts)
    included_descendants: list[str] = []
    if descendants_dir.exists() and descendants_dir.is_dir():
        for md_path in sorted(descendants_dir.rglob("*.md")):
            # Skip hidden files/dirs
            if any(seg.startswith(".") for seg in md_path.parts):
                continue
            included_descendants.append(Path(specs_prefix) / md_path.relative_to(specs_prefix))
        included_descendants = [p.as_posix() for p in included_descendants]

    # Determine missing ancestors
    missing_ancestors: list[str] = [p for p in ancestors if not (repo_root / p).exists()]
    # Only include existing ancestors
    existing_ancestors: list[str] = [p for p in ancestors if (repo_root / p).exists()]

    ordered: list[str] = []
    ordered.extend(existing_ancestors)
    ordered.append(self_path)
    ordered.extend(included_descendants)

    # Write manifest
    context_manifest = {
        "included": ordered,
        "missing_ancestors": missing_ancestors,
    }
    write_text_file(dest_dir / "context_manifest.json", json.dumps(context_manifest, indent=2) + "\n")

    # Write bundle
    bundle_lines: list[str] = []
    for rel_path in ordered:
        abs_path = repo_root / rel_path
        if not abs_path.exists():
            # Should not happen since ordered excludes missing ancestors
            continue
        bundle_lines.append(f"--- BEGIN {rel_path} ---")
        try:
            content = abs_path.read_text(encoding="utf-8")
        except Exception as ex:
            content = f"[ERROR READING FILE: {ex}]\n"
        # Ensure trailing newline
        if not content.endswith("\n"):
            content = content + "\n"
        bundle_lines.append(content)
        bundle_lines.append(f"--- END {rel_path} ---\n")
    write_text_file(dest_dir / "context_bundle.txt", "\n".join(bundle_lines))

    # Compute per-file digests and overall digest
    file_sha256: dict[str, str] = {}
    hasher = hashlib.sha256()
    for rel_path in ordered:
        abs_path = repo_root / rel_path
        try:
            data = abs_path.read_bytes()
        except Exception:
            data = b""
        digest = hashlib.sha256(data).hexdigest()
        file_sha256[rel_path] = digest
        hasher.update(rel_path.encode("utf-8") + b"\0" + digest.encode("ascii"))
    overall = hasher.hexdigest()
    return {"included": ordered, "file_sha256": file_sha256, "overall_sha256": overall}


def load_manifest_if_exists(dest_dir: Path) -> Optional[dict]:
    manifest_path = dest_dir / "manifest.json"
    if not manifest_path.exists():
        return None
    try:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        return None


def is_up_to_date(prev_manifest: dict, ctx: dict[str, object]) -> bool:
    try:
        prev = prev_manifest.get("context_digests", {})
        if not prev:
            return False
        return prev.get("overall_sha256") == ctx.get("overall_sha256") and prev_manifest.get("template_catalog_version") == "builtin-0.1" and prev_manifest.get("build_tool_version") == BUILD_TOOL_VERSION
    except Exception:
        return False


def write_if_changed(path: Path, content: str) -> None:
    try:
        if path.exists():
            current = path.read_text(encoding="utf-8")
            if current == content:
                return
    except Exception:
        pass
    write_text_file(path, content)


if __name__ == "__main__":
    main()


