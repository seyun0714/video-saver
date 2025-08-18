// lib/utils/constants.dart

const String videoObserverJS = r'''
// 기존 옵저버가 있다면 재사용하거나 새로 만듭니다.
window.videoSaverObserver?.disconnect();

const debouncedRun = () => {
  clearTimeout(window.debounceTimer);
  window.debounceTimer = setTimeout(findAllVideos, 500);
};

function addDownloadButton(video) {
  const parent = video.parentElement;
  if (!parent || parent.querySelector('.video-saver-btn')) {
    return;
  }
  if (window.getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }  


  const btn = document.createElement('div');
  btn.className = 'video-saver-btn';
  btn.innerHTML = '<span>⬇</span>';
  
  // 스타일 적용
  Object.assign(btn.style, {
    position: 'absolute',
    right: '10px', bottom: '10px',
    width: '40px', height: '40px',
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: '50%', zIndex: '2147483647',
    display: 'flex', alignItems: 'center',
    justifyContent: 'center', cursor: 'pointer',
    color: 'white'
  });

  // 클릭 이벤트가 비디오로 전파되는 것을 막는 가장 확실한 방법
  btn.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    
    console.log("VideoSaver: Download button clicked.");

    const sources = [];
    const sourceTags = video.querySelectorAll('source');
    
    sourceTags.forEach(source => {
      if (source.src && !source.src.startsWith('blob:')) {
        sources.push({ url: source.src, label: source.getAttribute('size') || source.getAttribute('title') || 'SD' });
      }
    });

    if (sources.length === 0 && video.currentSrc && !video.currentSrc.startsWith('blob:')) {
       sources.push({ url: video.currentSrc, label: 'Default' });
    }
    
    if (sources.length > 0) {
      console.log(`VideoSaver: Found ${sources.length} source(s). Calling Flutter.`);
      window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify({ sources: sources }));
    } else {
      console.log("VideoSaver: No downloadable sources found for this video.");
    }
  }, true); // Use capture phase to handle the event first

  parent.appendChild(btn);
}

function findAllVideos() {
  document.querySelectorAll('video').forEach(addDownloadButton);
  document.querySelectorAll('iframe').forEach(frame => {
    try {
      const doc = frame.contentDocument || frame.contentWindow.document;
      if (doc) {
        doc.querySelectorAll('video').forEach(addDownloadButton);
      }
    } catch (e) { /* Cross-origin iframe */ }
  });
}

findAllVideos();
window.videoSaverObserver = new MutationObserver(debouncedRun);
window.videoSaverObserver.observe(document.body, {
  childList: true,
  subtree: true
});
document.body.addEventListener('click', function() {
  window.flutter_inappwebview.callHandler('onWebViewTapped');
}, true);
''';
