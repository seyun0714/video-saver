// lib/utils/constants.dart

// JS: <video> 감지 + 우하단 버튼 삽입
const String videoObserverJS = '''
 // 개선된 JavaScript 코드
const videoSaverObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    if (mutation.type === 'childList') {
      mutation.addedNodes.forEach(node => {
        if (node.nodeType === 1) { // ELEMENT_NODE
          // 새로 추가된 노드 또는 그 자식 노드에서 video 태그를 찾음
          const videos = node.matches('video') ? [node] : node.querySelectorAll('video');
          addDownloadButton(videos);
        }
      });
    }
  }
});

function addDownloadButton(videos) {
  videos.forEach((video) => {
    // 이미 버튼이 추가된 비디오는 건너뜀
    if (video.parentElement.querySelector('.video-saver-btn')) {
      return;
    }

    const btn = document.createElement('button');
    btn.innerText = '⬇';
    btn.className = 'video-saver-btn'; // 중복 추가를 막기 위한 클래스
    btn.style.position = 'absolute';
    btn.style.right = '8px';
    btn.style.bottom = '8px';
    btn.style.zIndex = 999999;
    btn.style.backgroundColor = 'rgba(0,0,0,0.6)';
    btn.style.color = 'white';
    btn.style.border = 'none';
    btn.style.borderRadius = '4px';
    btn.style.fontSize = '16px';
    btn.style.cursor = 'pointer';

    btn.onclick = (e) => {
      e.stopPropagation(); // 비디오 재생/일시정지 이벤트 방지
      const sources = [];
      
      // 1. <source> 태그에서 화질별 URL 수집
      const sourceTags = video.querySelectorAll('source');
      sourceTags.forEach(source => {
        if (source.src && !source.src.startsWith('blob:')) {
          sources.push({
            url: source.src,
            label: source.getAttribute('size') || source.getAttribute('title') || 'SD'
          });
        }
      });

      // 2. <source> 태그가 없는 경우, video 태그의 src 속성 사용
      if (sources.length === 0 && video.currentSrc && !video.currentSrc.startsWith('blob:')) {
         sources.push({
           url: video.currentSrc,
           label: 'Default'
         });
      }
      
      // 3. 수집된 소스가 있을 경우에만 Flutter로 데이터 전송
      if (sources.length > 0) {
        window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify({
          page: location.href,
          sources: sources
        }));
      }
    };

    video.parentElement.style.position = 'relative';
    video.parentElement.appendChild(btn);
  });
}

function observeVideosInFrames() {
    // 현재 문서의 비디오에 버튼 추가
    addDownloadButton(document.querySelectorAll('video'));
    
    // iframe 내부의 비디오에도 버튼 추가
    document.querySelectorAll('iframe').forEach(frame => {
        try {
            const doc = frame.contentDocument || frame.contentWindow.document;
            if (doc) {
                addDownloadButton(doc.querySelectorAll('video'));
            }
        } catch(e) {
            // console.error('Cannot access iframe content:', e);
        }
    });
}


// 초기 실행
observeVideosInFrames();

// DOM 변경 감지 시작
videoSaverObserver.observe(document.body, {
  childList: true,
  subtree: true
});
''';
