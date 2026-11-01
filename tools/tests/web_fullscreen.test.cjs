const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(require('node:path').join(__dirname, '../web_fullscreen.js'), 'utf8');

function browser({ua = 'Android', platform = '', touch = 0, supported = true, installed = false, reject = false} = {}) {
    function element() {
        return {hidden:false, disabled:false, textContent:'', dataset:{}, attrs:{}, events:{},
            style:{setProperty() {}}, append() {}, contains(node) {return node === this;},
            setAttribute(k,v) {this.attrs[k]=v;}, getAttribute(k) {return this.attrs[k];},
            addEventListener(k,fn) {this.events[k]=fn;}, querySelector(k) {return nodes[k];}};
    }
    const nodes = Object.fromEntries(['.gate','.message','.enter','.toggle','path'].map(k => [k, element()]));
    const root = element(), events = {}, window = {addEventListener() {}};
    const document = {documentElement:root, head:element(), body:element(), fullscreenEnabled:supported,
        fullscreenElement:null, createElement:element, addEventListener(k,fn) {events[k]=fn;}};
    let requests = 0;
    if (supported) root.requestFullscreen = async () => {
        requests++;
        if (reject) throw new Error('denied');
        document.fullscreenElement = root;
        events.fullscreenchange();
    };
    document.exitFullscreen = async () => {document.fullscreenElement=null; events.fullscreenchange();};
    vm.runInNewContext(source, {window, document, navigator:{userAgent:ua, platform, maxTouchPoints:touch},
        matchMedia: q => ({matches:installed && q.includes('standalone'), addEventListener() {}})});
    const states = [];
    window.rubyFullscreen?.connectGame(value => states.push(value));
    return {nodes, document, events, window, states, requests:() => requests};
}

test('mobile starts blocked, resumes in fullscreen, pauses on browser exit and resumes again', async () => {
    const b = browser();
    assert.deepEqual(b.states, [true]);
    await b.nodes['.enter'].events.click();
    assert.equal(b.states.at(-1), false);
    assert.equal(b.nodes['.gate'].hidden, true);
    assert.equal(b.nodes['.toggle'].attrs['aria-label'], 'Exit fullscreen');
    await b.nodes['.toggle'].events.click();
    assert.equal(b.states.at(-1), true);
    assert.match(b.nodes['.message'].textContent, /Paused/);
    await b.nodes['.enter'].events.click();
    assert.equal(b.states.at(-1), false);
    assert.equal(b.requests(), 2);
});
test('desktop and a touch-capable Windows desktop get no mobile shell', () => {
    assert.equal(browser({ua:'Windows NT Chrome', touch:10}).window.rubyFullscreen, undefined);
});
test('iPad desktop agent gets the mobile shell', () => {
    assert.ok(browser({ua:'Macintosh Safari',platform:'MacIntel',touch:5}).window.rubyFullscreen);
});
test('installed apps start without the fullscreen gate or redundant toggle', () => {
    const b = browser({installed:true});
    assert.deepEqual(b.states, [false]);
    assert.equal(b.nodes['.toggle'].hidden, true);
});
test('unsupported browsers have an explicit playable fallback', async () => {
    const b = browser({ua:'iPhone Safari', supported:false});
    assert.equal(b.states.at(-1), true);
    assert.equal(b.nodes['.enter'].textContent, 'Play in browser');
    await b.nodes['.enter'].events.click();
    assert.equal(b.states.at(-1), false);
});
test('denied requests stay paused and allow a retry', async () => {
    const b = browser({reject:true});
    await b.nodes['.enter'].events.click();
    assert.equal(b.states.at(-1), true);
    assert.equal(b.nodes['.enter'].disabled, false);
    assert.match(b.nodes['.message'].textContent, /unavailable/);
    await b.nodes['.enter'].events.click();
    assert.equal(b.requests(), 2);
});
