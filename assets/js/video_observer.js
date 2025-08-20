// assets/js/video_observer.js
(function () {
    'use strict';

    const DEBUG_MODE = true;
    const log = (message, data) => {
        if (DEBUG_MODE) {
            if (data) {
                console.log('VideoSaver:', message, JSON.stringify(data, null, 2));
            } else {
                console.log('VideoSaver:', message);
            }
        }
    };

    const foundMediaUrls = new Set();
    const originalFetch = window.fetch;
    const originalXhrOpen = window.XMLHttpRequest.prototype.open;

    function getCleanUrl(url) {
        try {
            const urlObj = new URL(url);
            urlObj.searchParams.delete('bytestart');
            urlObj.searchParams.delete('byteend');
            const efg = urlObj.searchParams.get('efg');
            if (efg) {
                const decodedEfg = atob(efg);
                if (decodedEfg.includes('audio')) {
                    return null;
                }
            }
            return urlObj.toString();
        } catch (e) {
            return url;
        }
    }

    window.fetch = async function (...args) {
        const response = await originalFetch.apply(this, args);
        const cleanUrl = getCleanUrl(response.url);
        if (cleanUrl) {
            foundMediaUrls.add(cleanUrl);
        }
        return response;
    };

    window.XMLHttpRequest.prototype.open = function (method, url, ...args) {
        if (typeof url === 'string') {
            const cleanUrl = getCleanUrl(url);
            if (cleanUrl) {
                foundMediaUrls.add(cleanUrl);
            }
        }
        return originalXhrOpen.apply(this, [method, url, ...args]);
    };

    window.videoSaverObserver?.disconnect();

    const debouncedRun = () => {
        clearTimeout(window.debounceTimer);
        window.debounceTimer = setTimeout(() => findAllVideos(document.body), 500);
    };

    function getResolutionLabel(w, h) {
        if (!w || !h) return null;
        const shortSide = Math.min(w, h);
        if (shortSide >= 1080) return '1080p';
        if (shortSide >= 720) return '720p';
        return `${shortSide}p`;
    }

    // --- 👇 [핵심 수정] addDownloadButton 함수 전체를 교체합니다 ---
    function addDownloadButton(video) {
        const parent = video.parentElement;
        if (!parent || parent.querySelector('.video-saver-btn')) return;
        if (window.getComputedStyle(parent).position === 'static') {
            parent.style.position = 'relative';
        }

        const btn = document.createElement('div');
        btn.className = 'video-saver-btn';
        btn.innerHTML = '<span>⬇</span>';
        Object.assign(btn.style, {
            position: 'absolute',
            right: '10px',
            bottom: '10px',
            width: '40px',
            height: '40px',
            backgroundColor: 'rgba(0, 0, 0, 0.7)',
            borderRadius: '50%',
            zIndex: '2147483647',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            color: 'white',
        });

        btn.addEventListener(
            'click',
            (e) => {
                e.preventDefault();
                e.stopPropagation();

                let sourcesList = [];
                let found = false;

                // 전략 1: 페이지 내 <script> 태그에서 JSON 데이터 직접 파싱 (인스타그램 등)
                try {
                    const scriptTags = document.querySelectorAll('script');
                    const videoUrlRegex = /"video_url":"(.*?)"/g;

                    for (const script of scriptTags) {
                        const text = script.textContent;
                        const match = videoUrlRegex.exec(text);
                        if (match && match[1]) {
                            // URL에서 유니코드 이스케이프(\u0026)를 실제 문자로 변환
                            const decodedUrl = match[1].replace(/\\u0026/g, '&');
                            const cleanUrl = getCleanUrl(decodedUrl);
                            if (cleanUrl) {
                                sourcesList.push({
                                    url: cleanUrl,
                                    label: `${getResolutionLabel(video.videoWidth, video.videoHeight) || 'HD'} `,
                                });
                                found = true;
                                break; // 가장 먼저 찾은 고화질 URL 하나만 사용
                            }
                        }
                    }
                } catch (error) {
                    log('Error during script parsing:', error);
                }

                // 전략 2: JSON 파싱 실패 시, 네트워크 감지 방식으로 복귀
                if (!found) {
                    const sources = new Map();
                    if (foundMediaUrls.size > 0) {
                        foundMediaUrls.forEach((url) => {
                            const label = getResolutionLabel(video.videoWidth, video.videoHeight) || 'Video';
                            sources.set(url, { url: url, label: `${label}` });
                        });
                    }
                    sourcesList = Array.from(sources.values());
                }

                log('===== Download Button Clicked =====');
                log('[Debug] Final list of sources being sent to Flutter:', sourcesList);
                log('===================================');

                if (sourcesList.length > 0) {
                    const payload = { sources: sourcesList, duration: video.duration || 0 };
                    window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify(payload));
                }
            },
            true
        );

        parent.appendChild(btn);
    }
    // --- 👆 [핵심 수정] ---

    function findAllVideos(rootNode) {
        if (!rootNode) return;
        rootNode.querySelectorAll('video').forEach(addDownloadButton);
        rootNode.querySelectorAll('*').forEach((el) => {
            if (el.shadowRoot) findAllVideos(el.shadowRoot);
        });
        rootNode.querySelectorAll('iframe').forEach((frame) => {
            try {
                const doc = frame.contentDocument || frame.contentWindow.document;
                if (doc) findAllVideos(doc.body);
            } catch (e) {
                /* ignore */
            }
        });
    }

    log('Observer script loaded and running.');
    findAllVideos(document.body);
    window.videoSaverObserver = new MutationObserver(debouncedRun);
    window.videoSaverObserver.observe(document.body, { childList: true, subtree: true, attributes: true });
})();
