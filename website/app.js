const lang = document.documentElement.lang === 'en' ? 'en' : 'zh';
let mode = document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
let release = null, toastTimer;
const demo = lang === 'zh' ? '界面展示均为虚构演示数据' : 'Screens show fictional demo measurements';
const mirrorReady = lang === 'zh' ? '国内网盘备用入口' : 'Alternative cloud download';
const screenNames = lang === 'zh'
  ? {calendar: '身体日历', trend: '变化趋势', settings: '个人设置'}
  : {calendar: 'Body calendar', trend: 'Trends', settings: 'Your settings'};

function shot(page) {
  return `/assets/${page}${lang === 'en' ? '-en' : ''}${mode === 'dark' ? '-dark' : ''}.png`;
}
function render() {
  document.querySelectorAll('[data-shot]').forEach(img => {
    img.src = shot(img.dataset.shot);
    img.alt = `Poise ${screenNames[img.dataset.shot]} — ${demo}`;
  });
  document.getElementById('heroShot').src = shot('calendar');
  updateThemeControls();
  if (release?.mirror) document.getElementById('mirrorHint').textContent = mirrorReady;
}
const systemTheme=matchMedia('(prefers-color-scheme: dark)');
function updateThemeControls(){
 document.documentElement.dataset.theme=mode;
 document.querySelector('meta[name="theme-color"]').content=mode==='dark'?'#0e1816':'#f6f8f6';
 const button=document.getElementById('themeToggle');
 const label=lang==='zh'?(mode==='dark'?'切换到浅色':'切换到深色'):(mode==='dark'?'Switch to light mode':'Switch to dark mode');
 button.setAttribute('aria-label',label);button.title=label;button.setAttribute('aria-pressed',String(mode==='dark'));
 button.firstElementChild.innerHTML=mode==='dark'?'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/></svg>':'<svg viewBox="0 0 24 24"><path d="M21 13a9 9 0 0 1-10-10A9 9 0 1 0 21 13Z"/></svg>';
 document.querySelectorAll('[data-mode]').forEach(b=>{const active=b.dataset.mode===mode;b.classList.toggle('selected',active);b.setAttribute('aria-pressed',String(active));});
}
function setTheme(next,persist=true){mode=next;if(persist){try{localStorage.setItem('poise-site-theme',mode);}catch{}}render();}
document.getElementById('themeToggle').addEventListener('click',()=>setTheme(mode==='dark'?'light':'dark'));
document.querySelectorAll('[data-mode]').forEach(button=>button.addEventListener('click',()=>setTheme(button.dataset.mode)));
systemTheme.addEventListener('change',e=>{let explicit=false;try{explicit=['light','dark'].includes(localStorage.getItem('poise-site-theme'));}catch{}if(!explicit)setTheme(e.matches?'dark':'light',false);});
function toast(text){const el=document.getElementById('toast');el.textContent=text;el.classList.add('visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('visible'),2600);}
document.getElementById('checksum').addEventListener('click',async()=>{if(!release)return;try{await navigator.clipboard.writeText(release.sha256);toast(lang==='zh'?'SHA-256 校验值已复制':'SHA-256 checksum copied');}catch{window.prompt('SHA-256',release.sha256);}});
fetch('/release.json?t='+Date.now(),{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('Release data unavailable');return r.json();}).then(data=>{release=data;document.getElementById('version').textContent='v'+data.version;document.getElementById('fileSize').textContent=data.size;document.getElementById('releaseNotes').href='https://github.com/FinnWang-CN/Poise/releases/tag/v'+data.version;const github=new URL(data.github);if(github.protocol==='https:'&&github.hostname==='github.com')document.getElementById('githubDownload').href=github.href;if(data.mirror){const u=new URL(data.mirror);if(u.protocol==='https:'){const a=document.getElementById('mirrorDownload');a.href=u.href;a.classList.remove('disabled');a.removeAttribute('aria-disabled');a.target='_blank';a.rel='noopener';}}render();}).catch(()=>toast(lang==='zh'?'下载信息加载失败，请刷新重试':'Could not load download details. Please refresh.'));
render();
