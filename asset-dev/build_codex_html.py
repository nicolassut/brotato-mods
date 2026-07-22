#!/usr/bin/env python3
"""Assemble the codex browser artifact: injects codex.json into the HTML shell."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = json.load(open(f"{HERE}/codex.json"))
REPO = "/Users/nicolassutcliffe/brotato-mods"
OUT  = f"{REPO}/gourmet_codex.html"          # artifact source (published to claude.ai)
INDEX = f"{REPO}/index.html"                 # Vercel serves this at the site root
os.makedirs(os.path.dirname(OUT), exist_ok=True)

MOD_CHAR_ORDER = ["Gourmet","Picky Eater","Dishwasher","Competitive Eater","Butcher","Zombie",
                  "Minimalist","Mime","Tourist","Ruminant","Slug","Blacksmith","Juggler","Mole"]

HTML = r"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Brotato: Gourmet Codex</title>
<style>
:root{
  --bg:#282420; --panel:#332e28; --panel2:#3c362e; --line:#4a423a; --ink:#f2ede4;
  --dim:#b5aa9c; --green:#8dc63f; --red:#e05a52; --mod:#8dc63f; --dlc:#5fb4d9; --base:#b5aa9c;
  --t0:#b9b2a6; --t1:#57a5e8; --t2:#b06ee0; --t3:#e0575f;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:var(--bg);color:var(--ink);
  font:15px/1.45 -apple-system,"Segoe UI",Roboto,sans-serif}
::selection{background:#8dc63f44}
.app{display:flex;min-height:100vh}
/* ---------- rail ---------- */
.rail{width:228px;flex:none;background:var(--panel);border-right:3px solid #1d1a16;
  padding:18px 14px;position:sticky;top:0;height:100vh;overflow-y:auto}
.logo{font-weight:900;font-size:19px;letter-spacing:.4px;line-height:1.15;margin:0 0 2px}
.logo em{color:var(--green);font-style:normal}
.sub{color:var(--dim);font-size:11.5px;margin:0 0 16px;letter-spacing:.4px;text-transform:uppercase}
.navgrp{margin:0 0 14px}
.navh{font-size:11px;text-transform:uppercase;letter-spacing:1.2px;color:var(--dim);margin:0 0 6px}
.navbtn{display:flex;justify-content:space-between;align-items:center;width:100%;
  background:none;border:2px solid transparent;border-radius:9px;color:var(--ink);
  font:inherit;font-weight:700;padding:7px 10px;cursor:pointer;text-align:left}
.navbtn:hover{background:var(--panel2)}
.navbtn.on{background:var(--panel2);border-color:var(--green)}
.navbtn .n{color:var(--dim);font-weight:600;font-size:12.5px;font-variant-numeric:tabular-nums}
.navbtn:focus-visible{outline:2px solid var(--green);outline-offset:2px}
/* ---------- main ---------- */
.main{flex:1;min-width:0;padding:20px 26px 60px}
.top{display:flex;gap:12px;align-items:center;margin-bottom:16px;flex-wrap:wrap}
.search{flex:1;min-width:220px;background:var(--panel);border:3px solid #1d1a16;border-radius:11px;
  color:var(--ink);font:inherit;padding:10px 14px}
.search::placeholder{color:var(--dim)}
.search:focus{outline:2px solid var(--green);outline-offset:1px}
.srcgrp{display:flex;gap:6px}
.chip{background:var(--panel);border:2px solid var(--line);border-radius:999px;color:var(--dim);
  font:inherit;font-size:12.5px;font-weight:700;padding:5px 12px;cursor:pointer}
.chip.on{color:var(--ink);border-color:var(--green)}
.chip:focus-visible{outline:2px solid var(--green);outline-offset:2px}
/* ---------- sections ---------- */
.sect{margin:0 0 26px}
.sect h2{font-size:13px;text-transform:uppercase;letter-spacing:1.6px;color:var(--dim);
  margin:0 0 10px;display:flex;align-items:center;gap:10px}
.sect h2 .tag{font-size:10.5px;border-radius:999px;padding:2px 9px;letter-spacing:.8px}
.tag.mod{background:#8dc63f22;color:var(--mod)}
.tag.base{background:#b5aa9c1e;color:var(--base)}
.tag.dlc{background:#5fb4d922;color:var(--dlc)}
.sect h2 .cnt{color:#7a7266;font-weight:600;letter-spacing:0}
.sect h2::after{content:"";flex:1;height:2px;background:var(--line);border-radius:2px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(196px,1fr));gap:10px}
.card{display:flex;gap:10px;align-items:center;background:var(--panel);border:3px solid #1d1a16;
  border-left-width:5px;border-radius:12px;padding:9px 11px;cursor:pointer;color:var(--ink);
  font:inherit;text-align:left;min-height:58px}
.card:hover{background:var(--panel2);transform:translateY(-1px)}
.card:focus-visible{outline:2px solid var(--green);outline-offset:2px}
.card img{width:38px;height:38px;flex:none;image-rendering:auto;object-fit:contain}
.card .noicon{width:38px;height:38px;flex:none;border-radius:8px;background:var(--panel2)}
.card .cn{font-weight:800;font-size:14px;line-height:1.2}
.card .cm{color:var(--dim);font-size:11.5px;margin-top:2px}
.card.t0{border-left-color:var(--t0)} .card.t1{border-left-color:var(--t1)}
.card.t2{border-left-color:var(--t2)} .card.t3{border-left-color:var(--t3)}
.card.nc{border-left-width:3px}
.empty{color:var(--dim);padding:30px 0;text-align:center}
/* ---------- detail ---------- */
.ov{position:fixed;inset:0;background:#000a;opacity:0;pointer-events:none;transition:opacity .15s}
.ov.on{opacity:1;pointer-events:auto}
.det{position:fixed;top:0;right:0;height:100vh;width:min(430px,94vw);background:var(--panel);
  border-left:3px solid #1d1a16;transform:translateX(102%);transition:transform .18s ease;
  overflow-y:auto;padding:22px 22px 40px}
.det.on{transform:none}
@media (prefers-reduced-motion:reduce){.det,.ov{transition:none}}
.det .close{position:absolute;top:14px;right:14px;background:var(--panel2);border:2px solid var(--line);
  border-radius:9px;color:var(--ink);font:inherit;font-weight:800;padding:4px 11px;cursor:pointer}
.det .close:hover{border-color:var(--green)}
.dhead{display:flex;gap:14px;align-items:center;margin:0 0 6px}
.dhead img{width:64px;height:64px;object-fit:contain}
.dhead h3{margin:0;font-size:22px;font-weight:900;letter-spacing:.3px}
.dmeta{display:flex;gap:6px;flex-wrap:wrap;margin:4px 0 14px}
.pill{font-size:11px;font-weight:800;letter-spacing:.7px;text-transform:uppercase;
  border-radius:999px;padding:3px 10px;border:2px solid var(--line);color:var(--dim)}
.pill.lim{color:#e6b450;border-color:#e6b450}
.pill.t0{color:var(--t0);border-color:var(--t0)} .pill.t1{color:var(--t1);border-color:var(--t1)}
.pill.t2{color:var(--t2);border-color:var(--t2)} .pill.t3{color:var(--t3);border-color:var(--t3)}
.pill.mod{color:var(--mod);border-color:var(--mod)} .pill.dlc{color:var(--dlc);border-color:var(--dlc)}
.fx{margin:0;padding:0;list-style:none;display:flex;flex-direction:column;gap:7px}
.fx li{background:var(--panel2);border-radius:9px;padding:8px 11px;font-size:14px;line-height:1.35}
.fx li.good{box-shadow:inset 3px 0 0 var(--green)}
.fx li.bad{box-shadow:inset 3px 0 0 var(--red)}
.tiers{display:flex;gap:6px;margin:14px 0 10px}
.tb{background:var(--panel2);border:2px solid var(--line);border-radius:9px;color:var(--dim);
  font:inherit;font-weight:800;padding:5px 13px;cursor:pointer}
.tb.on.t0{border-color:var(--t0);color:var(--t0)} .tb.on.t1{border-color:var(--t1);color:var(--t1)}
.tb.on.t2{border-color:var(--t2);color:var(--t2)} .tb.on.t3{border-color:var(--t3);color:var(--t3)}
.stats{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:0 0 12px}
.st{background:var(--panel2);border-radius:9px;padding:7px 11px}
.st .k{color:var(--dim);font-size:10.5px;text-transform:uppercase;letter-spacing:1px}
.st .v{font-weight:800;font-size:16px;font-variant-numeric:tabular-nums}
.dsec{font-size:11px;text-transform:uppercase;letter-spacing:1.2px;color:var(--dim);margin:16px 0 7px}
@media (max-width:760px){
  html,body{font-size:15px}
  .app{display:block}
  .rail{position:sticky;top:0;z-index:20;width:auto;height:auto;border-right:none;
    border-bottom:3px solid #1d1a16;display:block;padding:9px 10px 8px}
  .logo{font-size:16px;margin:0 0 8px}.sub{display:none}.navh{display:none}
  .navgrp{margin:0 0 7px}
  /* sections become a swipeable tab strip */
  #navSections{display:flex;gap:7px;overflow-x:auto;flex-wrap:nowrap;padding-bottom:2px;
    -webkit-overflow-scrolling:touch;scrollbar-width:none}
  #navSections::-webkit-scrollbar{display:none}
  #navSections .navbtn{flex:0 0 auto}
  #navSources,#navClasses{flex-direction:row!important;flex-wrap:wrap;gap:6px}
  .navbtn{padding:9px 15px;font-size:14px;min-height:42px}.navbtn .n{display:none}
  .chip{padding:8px 14px;font-size:13.5px}
  .main{padding:12px 12px 72px}
  .top{flex-direction:column;align-items:stretch;gap:9px}
  .search{min-width:0;width:100%;padding:12px 14px;font-size:16px}
  .srcgrp{flex-wrap:wrap}
  .grid{grid-template-columns:1fr;gap:9px}
  .card{min-height:66px;padding:11px 12px}
  .card img,.card .noicon{width:46px;height:46px}
  .card .cn{font-size:16px}.card .cm{font-size:13px}
  .det{width:100vw;max-width:100vw;left:0;right:0;border-radius:0;padding:20px 15px 44px}
  .dhead img{width:56px;height:56px}.dhead h3{font-size:20px}
  .fx li{font-size:15px}
  .stats{grid-template-columns:1fr 1fr}
}
</style>

<div class="app">
  <nav class="rail">
    <div>
      <p class="logo">BROTATO<br><em>GOURMET CODEX</em></p>
      <p class="sub">every character, weapon, item &amp; food</p>
    </div>
    <div class="navgrp" id="navSections"></div>
    <div class="navgrp">
      <p class="navh">Source</p>
      <div id="navSources" style="display:flex;flex-direction:column;gap:4px"></div>
    </div>
    <div class="navgrp" id="navClassGrp" style="display:none">
      <p class="navh">Class</p>
      <div id="navClasses" style="display:flex;flex-direction:column;gap:4px"></div>
    </div>
  </nav>

  <main class="main">
    <div class="top">
      <input id="q" class="search" type="search" placeholder="Search everything&hellip; (name or effect)" autocomplete="off">
    </div>
    <div id="content"></div>
  </main>
</div>

<div class="ov" id="ov"></div>
<aside class="det" id="det" aria-live="polite"></aside>

<script>
const DATA = __CODEX__;
const MOD_ORDER = __MOD_ORDER__;
const TIERN = ["Tier 1","Tier 2","Tier 3","Tier 4"];
const SRC = {mod:"Gourmet Mod", base:"Base Game", dlc:"Abyssal Terrors"};
const SRCORDER = ["mod","base","dlc"];

let section = "characters", srcFilter = "all", classFilter = "all", query = "";

DATA.characters.forEach(c=>{ if(c.source==="mod"){ c._o = MOD_ORDER.indexOf(c.name); if(c._o<0)c._o=99; } });

function esc(s){return String(s).replace(/[&<>"]/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[m]))}

function matches(e){
  if(classFilter!=="all" && !(e.classes && e.classes.includes(classFilter))) return false;
  if(!query) return true;
  const q=query.toLowerCase();
  if(e.name.toLowerCase().includes(q)) return true;
  const fx = e.effects || (e.tiers ? e.tiers.flatMap(t=>t.effects) : []);
  return fx.some(f=>f.t.toLowerCase().includes(q));
}

function sorted(list){
  if(section==="characters")
    return [...list].sort((a,b)=> (a._o??50)-(b._o??50) || a.name.localeCompare(b.name));
  if(section==="items")
    return [...list].sort((a,b)=> a.tier-b.tier || a.name.localeCompare(b.name));
  if(section==="foods")
    return [...list].sort((a,b)=> a.name.localeCompare(b.name));
  return [...list].sort((a,b)=> (a.kind===b.kind?0:a.kind==="Melee"?-1:1) || a.name.localeCompare(b.name));
}

function cardMeta(e){
  if(section==="items") return TIERN[e.tier]+" \u00b7 "+e.value+" mats"+(e.max_nb>0?" \u00b7 max "+e.max_nb:"");
  if(section==="weapons") return e.kind+(e.classes.length?" \u00b7 "+e.classes.join(", "):"")+" \u00b7 "+e.tiers.length+" tier"+(e.tiers.length>1?"s":"");
  if(section==="foods") return (e.spawner?("via "+e.spawner):"Food")+(e.stack_cap>0?" \u00b7 max "+e.stack_cap+" stacks":"");
  if(section==="structures") return "Spawner structure";
  if(section==="projectiles") return "Projectile: "+e.projectile;
  return (e.effects[0]?e.effects[0].t:"");
}

function render(){
  const all = DATA[section];
  const cont = document.getElementById("content");
  cont.innerHTML = "";
  let shown = 0;
  for(const src of SRCORDER){
    let list = all.filter(e=>e.source===src && (srcFilter==="all"||srcFilter===src) && matches(e));
    if(!list.length) continue;
    list = sorted(list);
    shown += list.length;
    const sec = document.createElement("section"); sec.className="sect";
    sec.innerHTML = `<h2><span class="tag ${src}">${SRC[src]}</span><span class="cnt">${list.length}</span></h2>`;
    const g = document.createElement("div"); g.className="grid";
    list.forEach(e=>{
      const b=document.createElement("button");
      const tier = section==="items" ? "t"+e.tier : (section==="weapons" ? "t"+(e.tiers[0]?.tier??0) : null);
      b.className = "card "+(tier??"nc");
      b.innerHTML = (e.icon?`<img src="${e.icon}" alt="">`:`<span class="noicon"></span>`)+
        `<span><span class="cn">${esc(e.name)}</span><br><span class="cm">${esc(cardMeta(e)).slice(0,60)}</span></span>`;
      b.onclick = ()=>openDetail(e);
      g.appendChild(b);
    });
    sec.appendChild(g); cont.appendChild(sec);
  }
  if(!shown) cont.innerHTML = `<p class="empty">Nothing matches \u201c${esc(query)}\u201d.</p>`;
}

function fxList(fx){
  if(!fx.length) return `<p class="empty" style="padding:8px 0">No effect lines \u2014 stat block only.</p>`;
  return `<ul class="fx">`+fx.map(f=>`<li class="${f.good?"good":"bad"}">${esc(f.t)}</li>`).join("")+`</ul>`;
}

function openDetail(e){
  const d=document.getElementById("det"), ov=document.getElementById("ov");
  let inner = `<button class="close" id="dClose">\u2715</button>
    <div class="dhead">${e.icon?`<img src="${e.icon}" alt="">`:""}<h3>${esc(e.name)}</h3></div>
    <div class="dmeta"><span class="pill ${e.source}">${SRC[e.source]}</span>`;
  if(section==="items"){ inner += `<span class="pill t${e.tier}">${TIERN[e.tier]}</span><span class="pill">${e.value} materials</span>`;
    if(e.max_nb>0) inner += `<span class="pill lim">Limited: ${e.max_nb}</span>`; }
  if(section==="weapons"){ inner += `<span class="pill">${e.kind}</span>`+e.classes.map(c=>`<span class="pill">${esc(c)}</span>`).join(""); }
  if(section==="foods"){ if(e.spawner) inner += `<span class="pill">via ${esc(e.spawner)}</span>`;
    if(e.stack_cap>0) inner += `<span class="pill lim">Max stacks: ${e.stack_cap}</span>`; }
  inner += `</div>`;
  if(section==="weapons"){
    if(e.held) inner += `<p class="dsec">In-game sprite</p><div style="background:var(--panel2);border-radius:10px;padding:16px;display:flex;justify-content:center;margin-bottom:6px"><img src="${e.held}" alt="" style="image-rendering:pixelated;max-width:100%"></div>`;
    inner += `<div class="tiers" id="tierTabs"></div><div id="tierBody"></div>`;
    d.innerHTML = inner;
    const tabs=d.querySelector("#tierTabs"), body=d.querySelector("#tierBody");
    e.tiers.forEach((t,i)=>{
      const b=document.createElement("button"); b.className="tb t"+t.tier; b.textContent=TIERN[t.tier];
      b.onclick=()=>{ tabs.querySelectorAll(".tb").forEach(x=>x.classList.remove("on")); b.classList.add("on"); showTier(t); };
      tabs.appendChild(b); if(i===0){ b.classList.add("on"); showTier(t); }
    });
    function showTier(t){
      const S=t.stats||{}; const rows=[];
      if("damage" in S) rows.push(["Damage",S.damage]);
      if("cooldown" in S) rows.push(["Cooldown",(S.cooldown/60).toFixed(2)+"s"]);
      if("crit_chance" in S) rows.push(["Crit chance",Math.round(S.crit_chance*100)+"%"]);
      if("crit_multiplier" in S) rows.push(["Crit mult","\u00d7"+S.crit_multiplier]);
      if("max_range" in S) rows.push(["Range",S.max_range]);
      if("knockback" in S) rows.push(["Knockback",S.knockback]);
      if("lifesteal" in S && S.lifesteal) rows.push(["Life steal",Math.round(S.lifesteal*100)+"%"]);
      rows.push(["Price",t.value+" mats"]);
      body.innerHTML = `<div class="stats">`+rows.map(r=>`<div class="st"><div class="k">${r[0]}</div><div class="v">${r[1]}</div></div>`).join("")+`</div>`+
        (t.effects.length?`<p class="dsec">Effects</p>`+fxList(t.effects):"");
    }
  } else {
    inner += `<p class="dsec">Effects</p>`+fxList(e.effects);
    d.innerHTML = inner;
  }
  d.querySelector("#dClose").onclick = closeDetail;
  d.classList.add("on"); ov.classList.add("on");
}
function closeDetail(){document.getElementById("det").classList.remove("on");document.getElementById("ov").classList.remove("on")}
document.getElementById("ov").onclick=closeDetail;
addEventListener("keydown",e=>{if(e.key==="Escape")closeDetail()});

/* nav */
const NS=document.getElementById("navSections");
[["characters","Characters"],["weapons","Weapons"],["items","Items"],["foods","Foods"],["structures","Structures"],["projectiles","Projectiles"]].forEach(([id,label])=>{
  const b=document.createElement("button"); b.className="navbtn"+(id===section?" on":"");
  b.innerHTML=`<span>${label}</span><span class="n">${DATA[id].length}</span>`;
  b.onclick=()=>{section=id;classFilter="all";
    document.getElementById("navClassGrp").style.display=(id==="weapons")?"":"none";
    buildClassChips();
    NS.querySelectorAll(".navbtn").forEach(x=>x.classList.remove("on"));b.classList.add("on");render();};
  NS.appendChild(b);
});
const NV=document.getElementById("navSources");
[["all","Everything"],["mod","Gourmet Mod"],["base","Base Game"],["dlc","Abyssal Terrors"]].forEach(([id,label])=>{
  const b=document.createElement("button"); b.className="chip"+(id==="all"?" on":"");
  b.textContent=label;
  b.onclick=()=>{srcFilter=id;NV.querySelectorAll(".chip").forEach(x=>x.classList.remove("on"));b.classList.add("on");render();};
  NV.appendChild(b);
});
const CLASSES=[...new Set(DATA.weapons.flatMap(w=>w.classes||[]))].filter(Boolean).sort();
const NC=document.getElementById("navClasses");
function buildClassChips(){
  NC.innerHTML="";
  [["all","All Classes"],...CLASSES.map(c=>[c,c])].forEach(([id,label])=>{
    const b=document.createElement("button"); b.className="chip"+(id===classFilter?" on":"");
    b.textContent=label;
    b.onclick=()=>{classFilter=id;NC.querySelectorAll(".chip").forEach(x=>x.classList.remove("on"));b.classList.add("on");render();};
    NC.appendChild(b);
  });
}
buildClassChips();
document.getElementById("q").addEventListener("input",e=>{query=e.target.value.trim();render();});
render();
</script>
"""

html = HTML.replace("__CODEX__", json.dumps(DATA)).replace("__MOD_ORDER__", json.dumps(MOD_CHAR_ORDER))
open(OUT, "w").write(html)
open(INDEX, "w").write(html)   # keep the Vercel deploy copy in sync with every rebuild
print("wrote", OUT, "+ index.html", round(os.path.getsize(OUT)/1024), "KB")
