const input = document.querySelector('#input');
const paper = document.querySelector('#paper');
const file = document.querySelector('#file');
const button = document.querySelector('#render');
const sample = document.querySelector('#sample');
const escapeHtml = value => value.replace(/[&<>]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[char]));

// Mirrors convertMathBody / convertInlineMath in HumanTyper.swift.
function bracedGroup(value, start) {
  if (value[start] !== '{') return null;
  let depth = 0;
  for (let index = start; index < value.length; index += 1) {
    if (value[index] === '{') depth += 1;
    if (value[index] === '}' && --depth === 0) return [value.slice(start + 1, index), index + 1];
  }
  return null;
}
function convertMathBody(body) {
  let result = body;
  for (;;) {
    const position = result.indexOf('\\frac');
    if (position < 0) break;
    let numeratorStart = position + 5;
    while (/\s/.test(result[numeratorStart] || '')) numeratorStart += 1;
    const numerator = bracedGroup(result, numeratorStart);
    if (!numerator) break;
    let denominatorStart = numerator[1];
    while (/\s/.test(result[denominatorStart] || '')) denominatorStart += 1;
    const denominator = bracedGroup(result, denominatorStart);
    if (!denominator) break;
    result = result.slice(0, position) + '(' + numerator[0] + ')/(' + denominator[0] + ')' + result.slice(denominator[1]);
  }
  for (;;) {
    const position = result.indexOf('\\boxed');
    if (position < 0) break;
    let contentStart = position + 6;
    while (/\s/.test(result[contentStart] || '')) contentStart += 1;
    const content = bracedGroup(result, contentStart);
    if (!content) break;
    result = result.slice(0, position) + content[0] + result.slice(content[1]);
  }
  result = result.replace(/\\frac\s*([A-Za-z0-9])\s*([A-Za-z0-9])/g, '$1/$2');
  while (/\\text\{([^{}]*)\}/.test(result)) result = result.replace(/\\text\{([^{}]*)\}/g, '$1');
  const subscripts = { 0:'₀', 1:'₁', 2:'₂', 3:'₃', 4:'₄', 5:'₅', 6:'₆', 7:'₇', 8:'₈', 9:'₉', i:'ᵢ', j:'ⱼ', n:'ₙ', '+':'₊', '-':'₋', '=':'₌', '(':'₍', ')':'₎' };
  while (/_\{([^{}]+)\}/.test(result)) result = result.replace(/_\{([^{}]+)\}/g, (_, value) => '_' + Array.from(value).map(char => subscripts[char] || char).join(''));
  const replacements = [
    ['\\leftrightarrow','↔'], ['\\Rightarrow','→'], ['\\Leftarrow','←'], ['\\rightarrow','→'], ['\\leftarrow','←'],
    ['\\subseteq','⊆'], ['\\supseteq','⊇'], ['\\langle','⟨'], ['\\rangle','⟩'], ['\\notin','∉'], ['\\infty','∞'],
    ['\\forall','∀'], ['\\exists','∃'], ['\\times','×'], ['\\approx','≈'], ['\\cdot','·'], ['\\neq','≠'],
    ['\\leq','≤'], ['\\geq','≥'], ['\\le','≤'], ['\\ge','≥'], ['\\in','∈'], ['\\cup','∪'], ['\\cap','∩'],
    ['\\to','→'], ['\\mid',' | '], ['\\ln','ln'], ['\\{','{'], ['\\}','}'], ['{,}',',']
  ];
  for (const [command, symbol] of replacements) result = result.split(command).join(symbol);
  result = result.replace(/\\[;,! ]/g, '');
  for (const [plain, subscript] of Object.entries(subscripts)) result = result.split('_' + plain).join(subscript);
  return result;
}
function convertMathDelimiters(value) {
  return value.replace(/\\\[([\s\S]*?)\\\]/g, (_, body) => convertMathBody(body.replace(/\s+/g, ' ').trim()))
    .replace(/\\\(([\s\S]*?)\\\)/g, (_, body) => convertMathBody(body));
}
function applyDirectives(value) {
  return value.replace(/\x60?\[([^,\]\n]+),\s*([^\]\n]+)\]\x60?/g, '$2').replace(/\x60?\{save\}\x60?/g, '');
}
function inline(value) { return escapeHtml(convertMathDelimiters(applyDirectives(value))); }
function render() {
  const lines = convertMathDelimiters(input.value).split('\n');
  let html = '', index = 0;
  while (index < lines.length) {
    const table = lines[index].trim().match(/^\[\[TABLE (\d+)x(\d+)\]\]$/);
    if (table) {
      const rows = Number(table[1]), columns = Number(table[2]), data = [];
      for (let row = 0; row < rows && ++index < lines.length; row += 1) data.push(lines[index].split('|').map(cell => inline(cell.trim())));
      html += '<table>' + data.map(row => '<tr>' + Array.from({ length: columns }, (_, column) => '<td>' + (row[column] ?? '') + '</td>').join('') + '</tr>').join('') + '</table>';
      while (++index < lines.length && lines[index].trim() !== '[[ENDTABLE]]') {}
      index += 1;
      continue;
    }
    html += lines[index] ? '<p>' + inline(lines[index]) + '</p>' : '<p class="gap"></p>';
    index += 1;
  }
  paper.innerHTML = html || '<p class="hint">Nạp/dán nội dung rồi bấm “Cập nhật preview”.</p>';
}
button.onclick = render;
input.oninput = render;
input.onpaste = () => setTimeout(render, 0);
file.onchange = event => {
  const selected = event.target.files[0];
  if (!selected) return;
  const reader = new FileReader();
  reader.onload = () => { input.value = reader.result; render(); };
  reader.readAsText(selected);
};
sample.onclick = async () => { input.value = await fetch('/api/test-text').then(response => response.text()); render(); };
render();
addEventListener('pageshow', () => setTimeout(render, 0));
