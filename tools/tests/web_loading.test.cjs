const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(require('node:path').join(__dirname, '../web_loading.js'), 'utf8');
test('loading phrases rotate, leave errors alone, and stop with the loader', () => {
    const nodes = {
        'status': {display:'flex', visibility:'visible', insertBefore(label) {nodes.label = label;}},
        'status-progress': {display:'block'},
        'status-notice': {display:'none', textContent:'Engine error'},
    };
    let tick, cleared = false;
    vm.runInNewContext(source, {
        document: {head:{append() {}}, getElementById:id => nodes[id], createElement:() => ({})},
        getComputedStyle:node => node,
        setInterval:fn => {tick = fn; return 1;}, clearInterval:() => {cleared = true;},
    });
    assert.match(nodes.label.textContent, /Wrangling beasts/);
    tick();
    assert.match(nodes.label.textContent, /Calling Mom/);
    nodes['status-notice'].display = 'block';
    tick();
    assert.equal(nodes.label.hidden, true);
    assert.equal(nodes['status-notice'].textContent, 'Engine error');
    nodes.status.display = 'none';
    tick();
    assert.equal(cleared, true);
    assert.equal(nodes.label.hidden, true);
});
