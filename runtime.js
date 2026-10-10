/* Bahnbrecher – Standalone-Laufzeit
   Rendert die Vorlage aus <template id="tpl"> mit React.
   Unterstützt: {{pfad}} in Text und Attributen, <sc-if value>, <sc-for list as>,
   onClick/onChange-Handler und eine Klasse "Component extends DCLogic".
   Vereinsdaten werden pro Handy in localStorage gespeichert. */
(function () {
  var h = React.createElement;
  var STORE = 'bahnbrecher-v1';
  var PERSIST = ['clubName', 'adminPin', 'login', 'rules', 'fines', 'events', 'rights', 'beitragStd', 'beitragInd',
    'anchor', 'gastro', 'memberPins', 'exp', 'settled', 'players', 'guests', 'me'];

  if (/[?&]reset\b/.test(location.search)) {
    try { localStorage.removeItem(STORE); } catch (e) {}
    history.replaceState(null, '', location.pathname);
  }

  var ATTR = { 'class': 'className', 'for': 'htmlFor', 'inputmode': 'inputMode', 'onclick': 'onClick',
    'onchange': 'onChange', 'oninput': 'onInput', 'readonly': 'readOnly', 'maxlength': 'maxLength',
    'tabindex': 'tabIndex', 'autocomplete': 'autoComplete', 'viewbox': 'viewBox' };
  var HOLE = /\{\{\s*([^}]+?)\s*\}\}/g;
  var ONE = /^\{\{\s*([^}]+?)\s*\}\}$/;

  function lookup(path, scope) {
    var parts = path.split('.'), cur;
    for (var i = scope.length - 1; i >= 0; i--) {
      if (scope[i] && Object.prototype.hasOwnProperty.call(scope[i], parts[0])) { cur = scope[i][parts[0]]; break; }
    }
    for (var j = 1; j < parts.length && cur != null; j++) cur = cur[parts[j]];
    return cur;
  }
  function value(str, scope) {
    var m = ONE.exec(str);
    if (m) return lookup(m[1], scope);
    return str.replace(HOLE, function (_, p) { var v = lookup(p, scope); return v == null ? '' : String(v); });
  }
  function styleObj(str) {
    var o = {};
    str.split(';').forEach(function (decl) {
      var i = decl.indexOf(':'); if (i < 0) return;
      var k = decl.slice(0, i).trim(), v = decl.slice(i + 1).trim(); if (!k) return;
      if (k.indexOf('--') !== 0) k = k.replace(/-([a-z])/g, function (_, c) { return c.toUpperCase(); });
      o[k] = v.replace(/\s*!important$/, '');
    });
    return o;
  }

  function renderNodes(nodes, scope, keyBase) {
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
      var r = renderNode(nodes[i], scope, keyBase + '.' + i);
      if (r == null) continue;
      if (Array.isArray(r)) Array.prototype.push.apply(out, r); else out.push(r);
    }
    return out;
  }

  function renderNode(n, scope, key) {
    if (n.nodeType === 3) {
      var t = n.nodeValue;
      if (t.indexOf('{{') < 0) return t;
      var v = value(t, scope);
      return v == null ? '' : String(v);
    }
    if (n.nodeType !== 1) return null;
    var tag = n.tagName.toLowerCase();
    if (tag === 'sc-if') {
      return value(n.getAttribute('value') || '', scope) ? renderNodes(n.childNodes, scope, key) : null;
    }
    if (tag === 'sc-for') {
      var list = value(n.getAttribute('list') || '', scope) || [];
      var as = n.getAttribute('as') || 'item', out = [];
      list.forEach(function (item, idx) {
        var s = {}; s[as] = item;
        Array.prototype.push.apply(out, renderNodes(n.childNodes, scope.concat([s]), key + '[' + idx + ']'));
      });
      return out;
    }
    var props = { key: key };
    for (var a = 0; a < n.attributes.length; a++) {
      var at = n.attributes[a], name = at.name, raw = at.value;
      if (name.indexOf('hint-') === 0) continue;
      var lower = name.toLowerCase();
      var pname = ATTR[lower] || name;
      if (pname.indexOf('aria-') !== 0 && pname.indexOf('data-') !== 0 && pname.indexOf('-') > 0) {
        pname = pname.replace(/-([a-z])/g, function (_, c) { return c.toUpperCase(); });
      }
      var v = raw.indexOf('{{') >= 0 ? value(raw, scope) : raw;
      if (pname === 'style') { props.style = styleObj(String(v)); continue; }
      if (pname === 'disabled' || pname === 'readOnly' || pname === 'checked') { props[pname] = raw.indexOf('{{') >= 0 ? !!v : true; continue; }
      if (pname === 'value' && (tag === 'input' || tag === 'textarea' || tag === 'select')) { props.value = v == null ? '' : v; continue; }
      if (/^on[A-Z]/.test(pname) && typeof v !== 'function') continue;
      props[pname] = typeof v === 'boolean' && pname.indexOf('aria-') === 0 ? String(v) : v;
    }
    if ((tag === 'input' || tag === 'textarea') && 'value' in props && !props.onChange) props.readOnly = true;
    var kids = renderNodes(n.childNodes, scope, key);
    return h.apply(null, [tag, props].concat(kids));
  }

  var tplEl = document.getElementById('tpl');
  var ROOT = tplEl.content;

  window.DCLogic = class DCLogic extends React.Component {
    componentDidMount() {
      try {
        var saved = JSON.parse(localStorage.getItem(STORE) || 'null');
        if (saved && saved.data) {
          var patch = {};
          PERSIST.forEach(function (k) { if (k in saved.data) patch[k] = saved.data[k]; });
          if (saved.loggedIn) patch.screen = 'profile';
          this.setState(patch);
        }
      } catch (e) {}
    }
    componentDidUpdate() {
      try {
        var st = this.state, data = {};
        PERSIST.forEach(function (k) { if (k in st) data[k] = st[k]; });
        var loggedIn = ['profile', 'mpin', 'app'].indexOf(st.screen) >= 0;
        localStorage.setItem(STORE, JSON.stringify({ data: data, loggedIn: loggedIn }));
      } catch (e) {}
    }
    render() { return h(React.Fragment, null, renderNodes(ROOT.childNodes, [this.renderVals()], 'r')); }
  };

  window.mountApp = function (Comp) {
    ReactDOM.createRoot(document.getElementById('app')).render(h(Comp, {}));
  };
})();
