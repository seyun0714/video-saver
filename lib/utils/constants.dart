// lib/utils/constants.dart

const String videoObserverJS = r'''
// 기존 옵저버가 있다면 재사용하거나 새로 만듭니다.
window.videoSaverObserver?.disconnect();

const debouncedRun = () => {
  clearTimeout(window.debounceTimer);
  window.debounceTimer = setTimeout(findAllVideos, 500);
};

function getResolutionLabel(w, h) {
  if (!w || !h) return null;
  const shortSide = Math.min(w, h);
  if (shortSide >= 2160) return '4K';
  if (shortSide >= 1440) return '1440p';
  if (shortSide >= 1080) return '1080p';
  if (shortSide >= 720) return '720p';
  if (shortSide >= 480) return '480p';
  if (shortSide >= 360) return '360p';
  return `${shortSide}p`;
}

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
        const resLabel = getResolutionLabel(source.getAttribute('width'), source.getAttribute('height')) || source.getAttribute('res');
        const label = resLabel || source.getAttribute('size') || source.getAttribute('title') || 'SD';
        sources.push({ url: source.src, label: label });
      }
    });

    if (sources.length === 0 && video.currentSrc && !video.currentSrc.startsWith('blob:')) {
       const label = getResolutionLabel(video.videoWidth, video.videoHeight) || 'Default';
       sources.push({ url: video.currentSrc, label: label });
    }
    
    if (sources.length > 0) {
      console.log(`VideoSaver: Found ${sources.length} source(s). Calling Flutter.`);
      const payload = {
        sources: sources,
        duration: video.duration || 0
      };
      window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify(payload));
    } else {
      console.log("VideoSaver: No downloadable sources found for this video.");
    }
  }, true); // Use capture phase to handle the event first

  parent.appendChild(btn);
}

function findAllVideos(rootNode = document.body) {
  // 1. 현재 노드에서 비디오와 아이프레임 검색
  rootNode.querySelectorAll('video').forEach(addDownloadButton);
  rootNode.querySelectorAll('iframe').forEach(frame => {
    try {
      const doc = frame.contentDocument || frame.contentWindow.document;
      if (doc) {
        findAllVideos(doc.body); // 아이프레임 내부도 재귀적으로 탐색
      }
    } catch (e) { /* Cross-origin iframe */ }
  });

  // 2. 현재 노드의 Shadow DOM 내부를 재귀적으로 탐색
  const shadowRoots = rootNode.querySelectorAll('*');
  shadowRoots.forEach(el => {
    if (el.shadowRoot) {
      findAllVideos(el.shadowRoot);
    }
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
