(function(){
  var TOC=window.TOC||[], S=window.SEARCH||{topics:[],index:{},title:{}}, cur=document.body.getAttribute('data-topic');
  var root=document.documentElement;
  try{var th=localStorage.getItem('tcwhelp-theme');if(th)root.setAttribute('data-theme',th);}catch(e){}
  function fold(s){return s.toLowerCase().replace(/ß/g,'ss').replace(/æ/g,'ae').replace(/œ/g,'oe').normalize('NFD').replace(/[̀-ͯ]/g,'');}
  // tabla de contenido
  var path=[];
  function build(list,trail){
    var ul=document.createElement('ul');
    list.forEach(function(n){
      var li=document.createElement('li'),row=document.createElement('div'),tw=document.createElement('span'),a=document.createElement('a');
      tw.className='tw';a.href=n.u;a.textContent=n.t;
      var t2=trail.concat([n]);
      if(n.u===cur){a.className='cur';path=t2;}
      row.appendChild(tw);row.appendChild(a);li.appendChild(row);
      if(n.c&&n.c.length){tw.textContent='▾';var sub=build(n.c,t2);li.appendChild(sub);
        tw.onclick=function(){var c=li.classList.toggle('closed');tw.textContent=c?'▸':'▾';};}
      ul.appendChild(li);
    });
    return ul;
  }
  var toc=document.getElementById('toc');
  if(toc){toc.appendChild(build(TOC,[]));
    // colapsar lo que no esta en el camino actual
    var onPath={};path.forEach(function(n){onPath[n.u]=1;});
    toc.querySelectorAll('li').forEach(function(li){var a=li.querySelector(':scope>div>a'),sub=li.querySelector(':scope>ul');
      if(sub&&a&&!onPath[a.getAttribute('href')]){li.classList.add('closed');li.querySelector('.tw').textContent='▸';}});
    var c=toc.querySelector('a.cur');if(c)c.scrollIntoView({block:'center'});}
  var cr=document.getElementById('crumbs');
  if(cr)cr.innerHTML=path.slice(0,-1).map(function(n){return '<a href="'+n.u+'">'+n.t.replace(/</g,'&lt;')+'</a>';}).join(' › ');
  // buscador
  var q=document.getElementById('q'),res=document.getElementById('results');
  function search(text){
    var terms=fold(text).match(/[a-z0-9]{2,}/g);
    if(!terms){res.hidden=true;return;}
    var sets=terms.map(function(t){var out={};Object.keys(S.index).forEach(function(w){if(w.indexOf(t)===0)S.index[w].forEach(function(i){out[i]=1;});});return out;});
    var ids=Object.keys(sets[0]).filter(function(i){return sets.every(function(s){return s[i];});}).map(Number);
    ids=ids.map(function(i){var sc=0;terms.forEach(function(t){Object.keys(S.title||{}).forEach(function(w){if(w.indexOf(t)===0&&S.title[w].indexOf(i)>=0)sc+=2;});});return [i,sc];}).sort(function(a,b){return b[1]-a[1]||a[0]-b[0];}).slice(0,30);
    res.innerHTML='';
    if(!ids.length){res.innerHTML='<a href="#"><small>Sin resultados</small></a>';res.hidden=false;return;}
    ids.forEach(function(p){var t=S.topics[p[0]],a=document.createElement('a');a.href=t.u;a.innerHTML='<b></b><small></small>';a.firstChild.textContent=t.t;a.lastChild.textContent=t.d||'';res.appendChild(a);});
    res.hidden=false;
  }
  if(q){q.addEventListener('input',function(){search(q.value);});
    document.addEventListener('keydown',function(e){if((e.ctrlKey||e.metaKey)&&e.key==='f'&&!e.shiftKey){}if(e.key==='/'&&document.activeElement!==q&&!/input|textarea/i.test(document.activeElement.tagName)){e.preventDefault();q.focus();}});
    document.addEventListener('click',function(e){if(!e.target.closest('.searchbox'))res.hidden=true;});}
  // menu movil y tema
  var m=document.getElementById('menu');if(m)m.onclick=function(){document.body.classList.toggle('open');};
  var tb=document.getElementById('theme');
  if(tb)tb.onclick=function(){var d=root.getAttribute('data-theme')==='dark';var nt=d?'light':'dark';root.setAttribute('data-theme',nt);try{localStorage.setItem('tcwhelp-theme',nt);}catch(e){}};
  // boton copiar en bloques de codigo
  document.querySelectorAll('article pre').forEach(function(pre){var b=document.createElement('button');b.className='copy';b.textContent='Copiar';
    b.onclick=function(){navigator.clipboard&&navigator.clipboard.writeText(pre.innerText).then(function(){b.textContent='Copiado';setTimeout(function(){b.textContent='Copiar';},1200);});};pre.appendChild(b);});
})();