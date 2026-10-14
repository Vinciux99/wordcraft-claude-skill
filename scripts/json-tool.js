// json-tool.js - tiny JSON helper used by artcraft-setup.sh on macOS.
// Runs under JavaScript for Automation (osascript -l JavaScript, built into macOS)
// and under Node.js (used by the CI tests). No dependencies.
//
// Commands:
//   get <file> <dotted.path> [--var k=v ...]   print a value ({placeholders} expanded)
//        strings: printed as-is; arrays: one element per line; null/missing: empty line
//   mcp-set <configFile> <server> <command> <argsJson>   add/replace mcpServers.<server> (keeps everything else)
//   mcp-has <configFile> <server>              print "yes" or "no"
//   validate <file>                            exit 0 if the file is valid JSON
var IS_NODE = (typeof process !== 'undefined') && process.versions && process.versions.node;
var fs = IS_NODE ? require('fs') : null;
if (!IS_NODE) { ObjC.import('Foundation'); }

function readFile(p) {
  if (IS_NODE) return fs.readFileSync(p, 'utf8');
  var s = $.NSString.stringWithContentsOfFileEncodingError($(p), $.NSUTF8StringEncoding, $());
  if (!s || s.isNil()) throw new Error('cannot read ' + p);
  return ObjC.unwrap(s);
}
function writeFile(p, text) {
  if (IS_NODE) { fs.writeFileSync(p, text, 'utf8'); return; }
  var ns = $(text);
  var ok = ns.writeToFileAtomicallyEncodingError($(p), true, $.NSUTF8StringEncoding, $());
  if (!ok) throw new Error('cannot write ' + p);
}
function exists(p) {
  if (IS_NODE) return fs.existsSync(p);
  return $.NSFileManager.defaultManager.fileExistsAtPath($(p));
}
function out(s) {
  if (IS_NODE) { process.stdout.write(s + '\n'); return; }
  return s; // JXA run() return value is printed by osascript
}

function parseVars(args) {
  var vars = {}, rest = [];
  for (var i = 0; i < args.length; i++) {
    if (args[i] === '--var' && i + 1 < args.length) {
      var kv = String(args[++i]); var eq = kv.indexOf('=');
      if (eq > 0) vars[kv.slice(0, eq)] = kv.slice(eq + 1);
    } else rest.push(String(args[i]));
  }
  return { vars: vars, rest: rest };
}
function expand(v, vars) {
  if (typeof v !== 'string') return v;
  return v.replace(/\{([A-Za-z]+)\}/g, function (m, k) { return Object.prototype.hasOwnProperty.call(vars, k) ? vars[k] : m; });
}
function getPath(obj, path) {
  var cur = obj, parts = path.split('.');
  for (var i = 0; i < parts.length; i++) {
    if (cur === null || cur === undefined) return undefined;
    cur = cur[parts[i]];
  }
  return cur;
}

function main(argv) {
  var cmd = argv[0];
  if (cmd === 'get') {
    var p = parseVars(argv.slice(1));
    var data = JSON.parse(readFile(p.rest[0]));
    var val = getPath(data, p.rest[1]);
    if (val === undefined || val === null) return out('');
    if (Array.isArray(val)) return out(val.map(function (x) { return String(expand(x, p.vars)); }).join('\n'));
    if (typeof val === 'object') return out(JSON.stringify(val));
    return out(String(expand(val, p.vars)));
  }
  if (cmd === 'mcp-set') {
    var file = argv[1], server = argv[2], command = argv[3], args = JSON.parse(argv[4]);
    var cfg = {};
    if (exists(file)) {
      var raw = readFile(file);
      if (raw.replace(/\s/g, '').length > 0) cfg = JSON.parse(raw);
    }
    if (typeof cfg !== 'object' || cfg === null || Array.isArray(cfg)) throw new Error('config is not a JSON object');
    if (!cfg.mcpServers || typeof cfg.mcpServers !== 'object') cfg.mcpServers = {};
    cfg.mcpServers[server] = { command: command, args: args };
    writeFile(file, JSON.stringify(cfg, null, 2) + '\n');
    return out('ok');
  }
  if (cmd === 'mcp-has') {
    if (!exists(argv[1])) return out('no');
    var c = JSON.parse(readFile(argv[1]));
    return out(c && c.mcpServers && c.mcpServers[argv[2]] ? 'yes' : 'no');
  }
  if (cmd === 'quote') return out(JSON.stringify(String(argv[1])));
  if (cmd === 'validate') { JSON.parse(readFile(argv[1])); return out('ok'); }
  throw new Error('unknown command: ' + cmd);
}

if (IS_NODE) {
  try { main(process.argv.slice(2)); } catch (e) { process.stderr.write(String(e.message || e) + '\n'); process.exit(1); }
} else {
  // osascript calls the global run(argv) and prints its return value.
  var run = function (argv) { return main(argv); };
}
