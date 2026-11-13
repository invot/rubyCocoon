/* Artwork surrounds the engine's real progress bar; errors remain owned by Godot. */
(() => {
    const bar = document.getElementById('status-progress');
    const overlay = document.getElementById('status');
    if (!bar || !overlay) return;
    const library = window.RC_LOADING || {slides: ['01-flying.jpg'], captions: ['Counting egg freckles...']};
    const style = document.createElement('style');
    style.textContent = `
        @font-face {font-family:RCLoading;src:url('QuattrocentoSans-Regular.ttf')}
        @font-face {font-family:RCTitle;src:url('CormorantSC-Bold.ttf');font-weight:bold}
        #status {overflow:hidden;background:#171923}
        #status-splash {display:none!important}
        .rc-slide {position:absolute;inset:0;width:100%;height:100%;object-fit:cover;
            opacity:0;transition:opacity 2s ease;pointer-events:none;z-index:0}
        .rc-slide.rc-active {opacity:1}
        @keyframes rc-zoom {from {transform:scale(1)} to {transform:scale(1.07)}}
        #rc-title,#rc-loading-panel {position:absolute;left:50%;transform:translateX(-50%);
            box-sizing:border-box;border-radius:12px;background:#faf5f1;color:#222127;
            box-shadow:0 5px 16px #0003,inset 0 1px #fff9,inset 0 -1px #29202715;z-index:2}
        #rc-title {top:max(20px,env(safe-area-inset-top));margin:0;padding:10px 28px;
            white-space:nowrap;font:bold clamp(32px,5vw,64px) RCTitle,serif;color:#782d36}
        #rc-loading-panel {bottom:max(28px,env(safe-area-inset-bottom));width:min(720px,86%);
            padding:20px 24px}
        #rc-loading {margin:0 0 16px;font:clamp(24px,2.5vw,28px) RCLoading,sans-serif;
            text-align:center;min-height:1.3em}
        #status-progress {position:static!important;width:100%;height:20px;
            margin:0!important;accent-color:#a93a4b;border:0;border-radius:6px;overflow:hidden}
        #status-progress::-webkit-progress-bar {background:#e7dedd;border-radius:6px}
        #status-progress::-webkit-progress-value {background:#a93a4b;border-radius:6px}
        #status-progress::-moz-progress-bar {background:#a93a4b;border-radius:6px}
        #status-notice {z-index:5;max-width:85%;max-height:70%;overflow:auto}
        @media (prefers-reduced-motion:reduce) {.rc-slide {animation:none!important;transition:none}}
    `;
    document.head.append(style);
    const pictures = [0, 1].map(() => {
        const img = document.createElement('img');
        img.className = 'rc-slide';
        img.alt = '';
        overlay.insertBefore(img, bar);
        return img;
    });
    const title = document.createElement('h1');
    title.id = 'rc-title';
    title.textContent = 'Ruby Cocoon';
    overlay.insertBefore(title, bar);
    const panel = document.createElement('div');
    panel.id = 'rc-loading-panel';
    const label = document.createElement('p');
    label.id = 'rc-loading';
    label.setAttribute('role', 'status');
    label.setAttribute('aria-live', 'polite');
    overlay.insertBefore(panel, bar);
    panel.append(label, bar);
    bar.setAttribute('aria-label', 'Downloading Ruby Cocoon');
    let captionIndex = 0, slideIndex = 0, active = 0, stopped = false, swapping = false, seenVisible = false;
    label.textContent = library.captions[0];
    pictures[0].src = 'loading/' + library.slides[0];
    pictures[0].className = 'rc-slide rc-active';
    pictures[0].style.animation = 'rc-zoom 9s linear forwards';
    const hidden = node => !node || getComputedStyle(node).display === 'none' || getComputedStyle(node).visibility === 'hidden';
    function sync() {
        if (!hidden(overlay)) seenVisible = true;
        if (seenVisible && hidden(overlay)) {
            stopped = true;
            clearInterval(captionTimer);
            clearInterval(slideTimer);
        }
        const notice = document.getElementById('status-notice');
        const quiet = stopped || hidden(bar) || (notice && !hidden(notice));
        if (panel.hidden !== Boolean(quiet)) panel.hidden = Boolean(quiet);
        if (title.hidden !== Boolean(quiet)) title.hidden = Boolean(quiet);
        return quiet;
    }
    const captionTimer = setInterval(() => {
        if (sync()) return;
        captionIndex = (captionIndex + 1) % library.captions.length;
        label.textContent = library.captions[captionIndex];
    }, 3000);
    const slideTimer = setInterval(() => {
        if (sync() || swapping || library.slides.length < 2) return;
        swapping = true;
        const incoming = pictures[1 - active];
        incoming.onload = () => {
            if (!stopped) {
                incoming.style.animation = 'none';
                void incoming.offsetWidth;
                incoming.style.animation = 'rc-zoom 9s linear forwards';
                incoming.className = 'rc-slide rc-active';
                pictures[active].className = 'rc-slide';
                active = 1 - active;
            }
            swapping = false;
        };
        incoming.onerror = () => { swapping = false; };
        slideIndex = (slideIndex + 1) % library.slides.length;
        incoming.src = 'loading/' + library.slides[slideIndex];
    }, 7000);
    new MutationObserver(sync).observe(overlay, {attributes: true, childList: true, subtree: true});
})();
