/* Friendly loading messages share Godot's status overlay and disappear with it. */
(() => {
    const bar = document.getElementById('status-progress');
    const overlay = document.getElementById('status');
    if (!bar || !overlay) return;
    const phrases = ['Wrangling beasts...', 'Calling Mom...', 'Counting egg freckles...',
        'Untangling fishing lines...', 'Polishing the merge altar...', 'Asking the bees politely...',
        'Finding Jasper\'s other shoe...', 'Teaching eggs to sit still...'];
    const style = document.createElement('style');
    style.textContent = `
        @font-face {font-family:RCLoading;src:url('QuattrocentoSans-Regular.ttf')}
        #rc-loading {position:absolute;bottom:14%;left:50%;transform:translateX(-50%);
            max-width:80%;margin:0;padding:12px 24px;border-radius:12px;
            background:#faf5f1;color:#222127;box-shadow:0 4px 12px #0003;
            font:clamp(18px, 2.5vw, 28px) RCLoading,sans-serif;text-align:center}
    `;
    document.head.append(style);
    const label = document.createElement('p');
    label.id = 'rc-loading';
    overlay.insertBefore(label, bar);
    let index = 0;
    label.textContent = phrases[index];
    const timer = setInterval(() => {
        // Notices belong to the engine (including errors); never cover or replace them.
        const notice = document.getElementById('status-notice');
        label.hidden = getComputedStyle(bar).display === 'none';
        if (getComputedStyle(overlay).display === 'none' || getComputedStyle(overlay).visibility === 'hidden') {
            label.hidden = true;
            clearInterval(timer);
            return;
        }
        if (notice && getComputedStyle(notice).display !== 'none') label.hidden = true;
        index = (index + 1) % phrases.length;
        label.textContent = phrases[index];
    }, 2500);
})();
