const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../web_loading.js'), 'utf8');
const library = JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/loading/slideshow.json')));
function fixture(initiallyVisible = true) {
    const nodes = {};
    const timers = new Map();
    const cleared = [];
    class Element {
        constructor(tag) {this.tag = tag; this.style = {}; this.children = []; this.display = 'block'; this.visibility = 'visible';}
        setAttribute(k, v) {this[k] = v;}
        append(...children) {this.children.push(...children); for (const n of children) if(n.id) nodes[n.id] = n;}
        insertBefore(child) {this.append(child);}
    }
    nodes.status = new Element('div');
    nodes.status.visibility = initiallyVisible ? 'visible' : 'hidden';
    nodes['status-progress'] = new Element('progress');
    nodes['status-progress'].value = 0.37;
    nodes['status-notice'] = new Element('div');
    nodes['status-notice'].display = 'none';
    nodes['status-notice'].textContent = 'Engine error';
    let observer;
    vm.runInNewContext(source, {
        window: {RC_LOADING: library},
        document: {head: new Element('head'), getElementById: id => nodes[id], createElement: tag => new Element(tag)},
        getComputedStyle: n => n,
        setInterval: (fn, ms) => {timers.set(ms, fn); return ms;},
        clearInterval: id => cleared.push(id),
        MutationObserver: class {constructor(fn) {observer = fn;} observe() {}},
    });
    return {nodes, timers, cleared, observe: () => observer(), images: nodes.status.children.filter(n => n.tag === 'img')};
}
test('real library contains ten separate available landscape pictures', () => {
    assert.equal(library.slides.length, 10);
    assert.equal(new Set(library.slides).size, 10);
    for (const name of library.slides) assert.ok(fs.existsSync(path.join(__dirname, '../../assets/loading', name)));
    assert.ok(library.captions.length >= 20);
});
test('no title, rotating game captions, and engine-owned progress', () => {
    const {nodes, timers} = fixture();
    // (the game's name waits for the title screen's own plaque)
    assert.equal(nodes['rc-title'], undefined);
    assert.equal(nodes['rc-loading'].textContent, library.captions[0]);
    timers.get(3000)();
    assert.equal(nodes['rc-loading'].textContent, library.captions[1]);
    assert.equal(nodes['status-progress'].value, 0.37);
    assert.ok(nodes['rc-loading-panel'].children.includes(nodes['status-progress']));
});
test('two image slots fade only after load, and a failed picture does not blank the current image', () => {
    const {images, timers} = fixture();
    assert.equal(images.length, 2);
    assert.match(images[0].className, /rc-active/);
    timers.get(10000)();
    assert.match(images[0].className, /rc-active/);
    images[1].onerror();
    assert.match(images[0].className, /rc-active/);
    timers.get(10000)();
    images[1].onload();
    assert.match(images[1].className, /rc-active/);
    assert.equal(images[0].className, 'rc-slide');
    assert.match(images[1].style.animation, /rc-zoom/);
});
test('errors hide artwork captions, preserve notices, and completed loader stops timers', () => {
    const {nodes, timers, cleared, observe} = fixture();
    timers.get(3000)();
    nodes['status-notice'].display = 'block';
    observe();
    assert.equal(nodes['rc-loading-panel'].hidden, true);
    assert.equal(nodes['status-notice'].textContent, 'Engine error');
    nodes.status.display = 'none';
    observe();
    assert.deepEqual(cleared.sort((a, b) => a - b), [3000, 10000]);
});
test('initial hidden engine overlay does not cancel the slideshow before startup', () => {
    const {nodes, cleared, observe} = fixture(false);
    observe();
    assert.equal(cleared.length, 0);
    nodes.status.visibility = 'visible';
    observe();
    assert.equal(nodes['rc-loading-panel'].hidden, false);
    nodes.status.visibility = 'hidden';
    observe();
    assert.equal(cleared.length, 2);
});
