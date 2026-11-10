/* Mobile browser shell. No screen-size or touch-control-setting checks. */
(() => {
    const mobile = navigator.userAgentData?.mobile === true ||
        /Android|iPhone|iPad|iPod|Mobile|Silk|Kindle/i.test(navigator.userAgent) ||
        (/Macintosh|MacIntel/i.test(navigator.userAgent + navigator.platform) && navigator.maxTouchPoints > 1);
    // Shared with Prefs: touchscreen laptops remain desktop browsers.
    window.rubyMobileBrowser = mobile;
    if (!mobile) return;

    const root = document.documentElement;
    const standalone = matchMedia('(display-mode: standalone)');
    const installedFullscreen = matchMedia('(display-mode: fullscreen)');
    const installed = () => standalone.matches || installedFullscreen.matches || navigator.standalone === true;
    const fullscreen = () => !!(document.fullscreenElement || document.webkitFullscreenElement) || installed();
    const supported = () => !!((root.requestFullscreen && document.fullscreenEnabled !== false) ||
        (root.webkitRequestFullscreen && document.webkitFullscreenEnabled !== false));
    let callback, bypass = false, entered = fullscreen(), pending = false;
    const style = document.createElement('style');
    style.textContent = `
        @font-face {font-family:RCBody;src:url('Nunito.ttf');font-weight:200 1000}
        @font-face {font-family:RCHead;src:url('lunchds.ttf')}
        #rc-fullscreen {--unit:max(1px, min(100vh / 720, 100vw / 1280));--gem:#d6304f;
            --top:#0009;--bottom:#0009;--line:#df5d75;--ink:#fff;color:var(--ink);font-family:RCBody,sans-serif;font-weight:700}
        #rc-fullscreen [hidden] {display:none !important}
        #rc-fullscreen button {font:inherit;font-size:calc(32 * var(--unit));color:var(--ink);
            min-height:calc(80 * var(--unit));border:calc(2 * var(--unit)) solid var(--line);
            background:#0009;padding:calc(12 * var(--unit)) calc(24 * var(--unit));touch-action:manipulation;cursor:pointer}
        #rc-fullscreen button:focus-visible {outline:4px solid var(--ink);outline-offset:4px}
        #rc-fullscreen button:active {background:#fff;color:#101216;border-color:#fff}
        #rc-fullscreen button:disabled {opacity:.6;cursor:wait}
        #rc-fullscreen .gate {position:fixed;inset:0;z-index:2147483645;background:#03041aeb;
            display:flex;align-items:center;justify-content:center;padding:max(16px,env(safe-area-inset-top)) max(16px,env(safe-area-inset-right)) max(16px,env(safe-area-inset-bottom)) max(16px,env(safe-area-inset-left));box-sizing:border-box}
        #rc-fullscreen .card {max-width:calc(720 * var(--unit));max-height:90dvh;overflow:auto;
            padding:calc(32 * var(--unit));border:calc(3 * var(--unit)) solid var(--line);
            background:var(--top);-webkit-backdrop-filter:blur(12px);backdrop-filter:blur(12px);text-align:center}
        #rc-fullscreen h1 {font:calc(40 * var(--unit)) RCHead,sans-serif;color:var(--line);margin:0 0 calc(20 * var(--unit))}
        #rc-fullscreen p {font-size:calc(32 * var(--unit));line-height:1.2;margin:0 0 calc(24 * var(--unit))}
        #rc-fullscreen .toggle {position:fixed;z-index:2147483646;top:max(12px,env(safe-area-inset-top));
            right:max(12px,env(safe-area-inset-right));width:calc(80 * var(--unit));padding:calc(16 * var(--unit))}
        #rc-fullscreen svg {width:100%;height:calc(40 * var(--unit));display:block;pointer-events:none}
    `;
    document.head.append(style);
    const shell = document.createElement('div');
    shell.id = 'rc-fullscreen';
    shell.innerHTML = `<section class="gate" role="dialog" aria-modal="true" aria-labelledby="rc-fs-title">
        <div class="card"><h1 id="rc-fs-title">Ruby Cocoon</h1><p class="message"></p>
        <button class="enter" type="button">Play fullscreen</button></div></section>
        <button class="toggle" type="button" aria-label="Enter fullscreen" title="Enter fullscreen">
        <svg viewBox="0 0 32 32" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="3">
        <path d="M12 3H3v9m17-9h9v9M3 20v9h9m17-9v9h-9"/></svg></button>`;
    document.body.append(shell);
    const gate = shell.querySelector('.gate'), message = shell.querySelector('.message');
    const enter = shell.querySelector('.enter'), toggle = shell.querySelector('.toggle');
    const blocked = () => !fullscreen() && !bypass;
    function update() {
        const full = fullscreen();
        if (full) { entered = true; bypass = false; }
        gate.hidden = !blocked();
        toggle.hidden = installed();
        toggle.setAttribute('aria-label', full ? 'Exit fullscreen' : 'Enter fullscreen');
        toggle.title = toggle.getAttribute('aria-label');
        toggle.setAttribute('aria-pressed', String(full));
        toggle.querySelector('path').setAttribute('d', full ?
            'M3 12h9V3m8 0v9h9M12 29v-9H3m26 0h-9v9' :
            'M12 3H3v9m17-9h9v9M3 20v9h9m17-9v9h-9');
        message.textContent = supported() ? (entered ? 'Paused. Return to fullscreen to keep playing.' :
            'Enter fullscreen to begin your journey.') :
            'This browser cannot enter fullscreen. On iPhone, use Safari’s Share → Add to Home Screen, or play here.';
        enter.textContent = supported() ? (entered ? 'Resume fullscreen' : 'Play fullscreen') : 'Play in browser';
        callback?.(blocked());
    }
    async function request() {
        if (pending) return;
        if (!supported()) { bypass = true; update(); return; }
        pending = true; enter.disabled = toggle.disabled = true;
        try {
            // Fullscreen the document, so the icon and prompt remain above the canvas.
            await (root.requestFullscreen ? root.requestFullscreen() : root.webkitRequestFullscreen());
        } catch (_) {
            message.textContent = 'Fullscreen was unavailable. Tap to try again, or check your browser’s fullscreen permissions.';
        } finally { pending = false; enter.disabled = toggle.disabled = false; }
    }
    enter.addEventListener('click', request);
    toggle.addEventListener('click', async () => {
        if (!fullscreen()) { await request(); return; }
        try { await (document.exitFullscreen ? document.exitFullscreen() : document.webkitExitFullscreen()); }
        catch (_) { /* The existing fullscreen session is still usable. */ }
    });
    for (const type of ['fullscreenchange', 'webkitfullscreenchange']) document.addEventListener(type, update);
    for (const query of [standalone, installedFullscreen]) query.addEventListener('change', update);
    // Capture before Godot's canvas listeners; no overlay press reaches a new game screen.
    for (const type of ['pointerdown', 'pointerup', 'touchstart', 'touchend', 'mousedown', 'mouseup', 'click', 'keydown', 'keyup']) {
        window.addEventListener(type, event => {
            if (shell.contains(event.target)) {
                // Keep native button activation/focus, but stop bubbling to the canvas/document.
                return;
            }
            if (blocked()) { event.preventDefault(); event.stopImmediatePropagation(); }
        }, {capture:true, passive:false});
        shell.addEventListener(type, event => event.stopPropagation());
    }
    window.rubyFullscreen = {
        connectGame(fn) { callback = fn; update(); },
        theme(gem, top, bottom, line, ink) {
            for (const [key, value] of Object.entries({gem, top, bottom, line, ink})) shell.style.setProperty('--' + key, value);
        },
    };
    update();
})();
