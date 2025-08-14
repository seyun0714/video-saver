// lib/utils/constants.dart

// JS: <video> 감지 + 우하단 버튼 삽입
const String videoObserverJS = '''
  document.querySelectorAll('iframe').forEach(function(frame){
    try {
      const doc = frame.contentDocument || frame.contentWindow.document;
      if (!doc) return;
      doc.querySelectorAll('video').forEach(function(video){
        if (!video.__vs_hasButton) {
          const btn = document.createElement('button');
          btn.innerText = '⬇';
          btn.style.position = 'absolute';
          btn.style.right = '8px';
          btn.style.bottom = '8px';
          btn.style.zIndex = 999999;
          btn.onclick = function(){
            const src = video.currentSrc || video.src;
            if (src && !src.startsWith('blob:')) {
              window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify({page: location.href, sources:[{url: src, label: 'video'}]}));
            }
          };
          video.parentElement.style.position = 'relative';
          video.parentElement.appendChild(btn);
          video.__vs_hasButton = true;
        }
      });
    } catch(e){}
  });
''';
