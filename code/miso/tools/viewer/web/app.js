(function(){
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
    const lines = text.split(/?
/);
    let out = [];
    let inCode = false; let codeBuf = [];
    for(const line of lines){
      if(line.startsWith('```')){ if(inCode){ out.push('<pre><code>'+esc(codeBuf.join('
'))+'</code></pre>'); codeBuf=[]; inCode=false; } else { inCode=true; } continue; }
      if(inCode){ codeBuf.push(line); continue; }
      if(line.startsWith('# ')){ out.push('<h1>'+esc(line.slice(2).trim())+'</h1>'); continue; }
      if(line.startsWith('## ')){ out.push('<h2>'+esc(line.slice(3).trim())+'</h2>'); continue; }
      if(line.trim()===''){ out.push('<p></p>'); continue; }
      out.push('<p>'+esc(line)+'</p>');
    }
    return out.join('
');
  }

  function parseBundle(text){
    const files = {}; let current = null; let buf = [];
    const beginRe = /^--- BEGIN (.+) ---$/; const endRe = /^--- END (.+) ---$/;
    for(const raw of text.split(/?
/)){
      const m1 = raw.match(beginRe); const m2 = raw.match(endRe);
      if(m1){ current = m1[1]; buf=[]; continue; }
      if(m2){ if(current){ files[current]=buf.join('
'); current=null; buf=[]; } continue; }
      if(current){ buf.push(raw); }
    }
    return files;
  }

  function updateBreadcrumbs(specPath){
    const path = specPath.replace(/^specs\//,'').replace(/\.md$/, '');
    const parts = path.split('/');
    let acc = [];
    crumbsEl.innerHTML = parts.map((p,i)=>{ acc.push(p); const id = acc.join('/'); return '<a href="#'+id+'">'+p+'</a>'; }).join(' › ');
  }

  function renderChildren(files, specPath){
    const base = specPath.replace(/\.md$/,'');
    const folder = 'specs/'+base+'/';
    const children = Object.keys(files).filter(k=> k.startsWith(folder) && k!==specPath ).sort();
    if(children.length===0){ childrenEl.innerHTML = '<div style="color:#57606a">No child snippets yet.</div>'; return; }
    childrenEl.innerHTML = children.map(k=>{
      const title = (files[k].split(/?
/).find(l=>l.startsWith('# '))||'# Untitled').slice(2);
      const sumLine = files[k].split(/?
/).find(l=>/^\*.*\*$/.test(l.trim()));
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
        md = await fetch(url).then(r=> r.ok ? r.text() : '# Missing
');
      } catch(_e){
        md = '# Missing
';
      }
    }
    mdEl.innerHTML = renderMarkdown(md);
    renderChildren(files, specPath);
  }

  // Initial: default to specs/miso.md if no deep-link hash is present
  const initial = (location.hash? 'specs/'+location.hash.slice(1)+'.md' : 'specs/miso.md');
  load(initial);
})();
