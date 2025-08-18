const String videoObserverJS = r'''
// ===== VideoSaver Observer (blob / dynamic src / network candidates 지원) =====

// 기존 옵저버/패치 중복 방지
try { window.videoSaverObserver && window.videoSaverObserver.disconnect(); } catch(e) {}
if (window.__videoSaver_injected) {
  // 이미 주입됨
} else {
  window.__videoSaver_injected = true;

  // ---- 공용 유틸 ----
  const VS = {
    send(data) {
      try { window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify(data)); } catch(e) {}
    },
    isBlob(u){ return (u||'').startsWith('blob:'); },
    isMediaUrl(u){
      return /\.(mp4|webm|m4v|m3u8|mpd|ts|m4s)(\?|#|$)/i.test(u||'');
    },
    styleBtn(btn){
      Object.assign(btn.style, {
        position: 'absolute', right: '10px', bottom: '10px',
        width: '40px', height: '40px',
        backgroundColor: 'rgba(0,0,0,0.7)',
        borderRadius: '50%', zIndex: '2147483647',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer', color: 'white', userSelect: 'none'
      });
    },
    reportVideo(v, extra={}) {
      try {
        const srcAttr = v.getAttribute('src') || null;
        const srcNow  = v.currentSrc || srcAttr || null;
        const sources = [];
        v.querySelectorAll('source').forEach(s=>{
          if (s.src && !s.src.startsWith('blob:')) {
            sources.push({ url: s.src, label: s.getAttribute('size') || s.getAttribute('title') || 'SD' });
          }
        });
        if (!VS.isBlob(srcNow) && srcNow) {
          if (!sources.find(x=>x.url===srcNow)) sources.push({ url: srcNow, label: 'Default' });
        }
        const payload = {
          tag: 'video',
          poster: v.poster || null,
          duration: v.duration || 0,
          width: v.videoWidth || 0,
          height: v.videoHeight || 0,
          autoplay: !!v.autoplay, muted: !!v.muted, paused: !!v.paused,
          blob: VS.isBlob(srcNow),
          currentSrc: srcNow,
          sources,                                  // 직접 다운로드 가능한 URL들
          candidates: Array.from(VS.__candidates),  // 네트워크에서 수집한 후보(HLS/DASH 포함)
          ...extra
        };
        VS.send(payload);
      } catch(e) {}
    },
    __candidates: new Set(), // 네트워크에서 수집한 실제 URL 후보
  };

  // ---- 1) URL.createObjectURL 후킹: blob URL 생성 감지 ----
  (function(){
    const _orig = URL.createObjectURL;
    URL.createObjectURL = function(obj){
      const url = _orig.call(URL, obj);
      try {
        VS.send({ tag:'blob-create', createdBlobUrl:url, kind: obj?.constructor?.name || null, type: obj?.type || null });
      } catch(e){}
      return url;
    };
  })();

  // ---- 2) <video>.src setter 후킹: 동적 src 변경 감지 ----
  (function(){
    const desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
    if (desc && desc.configurable) {
      Object.defineProperty(HTMLMediaElement.prototype, 'src', {
        set: function(v){ desc.set.call(this, v); try { VS.reportVideo(this, {reason:'setter'}); } catch(e){} },
        get: function(){ return desc.get.call(this); }
      });
    }
  })();

  // ---- 3) fetch / XHR 패치: 실제 URL 후보 수집 ----
  (function(){
    // fetch
    const _fetch = window.fetch;
    window.fetch = function(input, init){
      const url = (typeof input === 'string') ? input : (input?.url || '');
      if (VS.isMediaUrl(url)) VS.__candidates.add(url);
      return _fetch.call(this, input, init).then(resp=>{
        try {
          const u = resp.url || url;
          if (VS.isMediaUrl(u)) VS.__candidates.add(u);
        } catch(e){}
        return resp;
      });
    };
    // XHR
    const _open = XMLHttpRequest.prototype.open;
    const _send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url){
      this.__vs_url = url;
      return _open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function(){
      this.addEventListener('loadend', function(){
        try {
          const u = this.responseURL || this.__vs_url || '';
          if (VS.isMediaUrl(u)) VS.__candidates.add(u);
        } catch(e){}
      });
      return _send.apply(this, arguments);
    };
  })();

  // ---- 4) 비디오에 버튼 붙이고, 이벤트로 최신 상태 리포트 ----
  function addDownloadButton(video) {
    const parent = video.parentElement;
    if (!parent || parent.querySelector('.video-saver-btn')) return;
    if (window.getComputedStyle(parent).position === 'static') parent.style.position = 'relative';

    const btn = document.createElement('div');
    btn.className = 'video-saver-btn';
    btn.innerHTML = '<span>⬇</span>';
    VS.styleBtn(btn);

    // ★ 재진입 방지 + 전파 완전 차단 + 버블링 단계
    btn.addEventListener('click', (e)=>{
      if (btn.dataset.vsBusy === '1') return;
      btn.dataset.vsBusy = '1';
      e.preventDefault();
      e.stopImmediatePropagation();

      // (선택) 눌림 표시 & 1초 후 해제 (앱에서 ACK 받은 뒤 해제하는 방식으로 바꿔도 됨)
      btn.style.opacity = '0.6';
      setTimeout(()=>{ btn.style.opacity = ''; btn.dataset.vsBusy = '0'; }, 1000);

      VS.reportVideo(video, {reason:'btn'});
    }, false);

    parent.appendChild(btn);

    // 이벤트 과다 리포트 방지: 꼭 필요한 것만
    const evs = ['loadedmetadata','loadeddata','canplay'];
    evs.forEach(evt => video.addEventListener(evt, ()=>VS.reportVideo(video, {reason:evt}), {passive:true}));
  }

  function findAllVideos(root=document){
    root.querySelectorAll('video').forEach(addDownloadButton);
    root.querySelectorAll('iframe').forEach(frame=>{
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (doc) findAllVideos(doc);
      } catch(e){ /* cross-origin */ }
    });
  }

  // ---- 5) DOM 변화 감지 (src/ poster 변경 포함) ----
  function debouncedRun(){
    clearTimeout(debouncedRun._t);
    debouncedRun._t = setTimeout(()=>findAllVideos(), 400);
  }

  findAllVideos();
  window.videoSaverObserver = new MutationObserver(debouncedRun);
  window.videoSaverObserver.observe(document.documentElement, {
    childList:true, subtree:true, attributes:true, attributeFilter:['src','poster']
  });

  // ---- 6) 전체 탭 이벤트: 버블링 단계 + 버튼 클릭은 무시 ----
  document.body.addEventListener('click', function(e){
    try {
      if (e.target && e.target.closest && e.target.closest('.video-saver-btn')) return;
      window.flutter_inappwebview.callHandler('onWebViewTapped');
    } catch(e) {}
  }, false);
}
''';
