const input = document.querySelector('#input');
const paper = document.querySelector('#paper');
const file = document.querySelector('#file');
const button = document.querySelector('#render');
const sample = document.querySelector('#sample');
const estimateTime = document.querySelector('#estimate-time');
const estimateDetail = document.querySelector('#estimate-detail');
let settings = null;
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

const segmenter = typeof Intl.Segmenter === 'function'
  ? new Intl.Segmenter('vi', { granularity: 'grapheme' })
  : null;
function characterCount(value) {
  return segmenter ? Array.from(segmenter.segment(value)).length : Array.from(value).length;
}
function setting(name, fallback) {
  const value = settings?.[name];
  return typeof value === typeof fallback ? value : fallback;
}
function formatDuration(seconds) {
  const rounded = Math.max(0, Math.round(seconds));
  const hours = Math.floor(rounded / 3600);
  const minutes = Math.floor((rounded % 3600) / 60);
  const rest = rounded % 60;
  return hours > 0
    ? hours + ':' + String(minutes).padStart(2, '0') + ':' + String(rest).padStart(2, '0')
    : minutes + ':' + String(rest).padStart(2, '0');
}
function estimateDocument(source) {
  const converted = convertMathDelimiters(source);
  const tablePattern = /\[\[TABLE\s+(\d+)x(\d+)\]\]\s*\n([\s\S]*?)\n\[\[ENDTABLE\]\]/gi;
  const tables = Array.from(converted.matchAll(tablePattern));
  const tableSeconds = tables.reduce((total, match) => total + Number(match[1]) + Number(match[2]), 0);
  const withoutTableSyntax = converted.replace(tablePattern, (_, rows, columns, body) =>
    body.split('\n').slice(0, Number(rows)).flatMap(row => row.split('|').slice(0, Number(columns))).map(cell => cell.trim()).join('')
  );
  const manualCorrections = Array.from(withoutTableSyntax.matchAll(/\x60?\[([^,\]\n]+),\s*([^\]\n]+)\]\x60?/g));
  const explicitSaves = Array.from(withoutTableSyntax.matchAll(/\x60?\{save\}\x60?/g)).length;
  const finalText = applyDirectives(withoutTableSyntax);
  const characters = characterCount(finalText);

  const wpm = setting('tocDoTuMoiPhut', 120);
  const base = 60 / Math.max(1, wpm * 5);
  let rhythmExtra = 0;
  if (setting('batNhipTuNhien', true)) {
    for (const character of Array.from(finalText)) {
      rhythmExtra += base * 0.03 + 0.0135;
      if (character === ' ') rhythmExtra += 0.0525;
      if (',;:'.includes(character)) rhythmExtra += 0.22;
      if ('.!?'.includes(character)) rhythmExtra += 0.525;
      if (character === '\n') rhythmExtra += 0.725;
    }
  }
  const rhythmPerCharacter = characters ? rhythmExtra / characters : 0;
  const saveSeconds = setting('choTruocLuuGiay', 5)
    + setting('xemLuuLichSuGiay', 5)
    + setting('choSauLuuGiay', 5)
    + 0.8;
  const historyAverage = (setting('soKyTuLuuToiThieu', 180) + setting('soKyTuLuuToiDa', 300)) / 2;
  const periodicSaves = setting('batLuuLichSu', true) ? characters / historyAverage : 0;
  const typoAverage = (setting('khoangKyTuLoiToiThieu', 80) + setting('khoangKyTuLoiToiDa', 160)) / 2;
  const typosPerCycle = (setting('soLoiMoiDotToiThieu', 1) + setting('soLoiMoiDotToiDa', 3)) / 2;
  const errorEnabled = setting('batLoiCoY', true) && setting('tyLeLoiPhanTram', 2.5) > 0;
  const automaticCorrections = errorEnabled
    ? Math.min(characters / typoAverage, (periodicSaves > 0 ? periodicSaves + 1 : 1) * typosPerCycle)
    : 0;
  const words = Math.max(1, finalText.trim().split(/\s+/).filter(Boolean).length);
  const wordLength = Math.max(4, characters / words);
  const phraseWords = (setting('soTuCumSaiToiThieu', 1) + setting('soTuCumSaiToiDa', 3)) / 2;
  const backspace = base * 0.875;
  const automaticCorrectionSeconds = wordLength * phraseWords * (base + rhythmPerCharacter + backspace);
  const manualSeconds = manualCorrections.reduce((total, match) =>
    total + saveSeconds + characterCount(match[1].trim()) * (base + rhythmPerCharacter + backspace), 0
  );
  const seconds = characters * (base + rhythmPerCharacter)
    + periodicSaves * saveSeconds
    + automaticCorrections * (saveSeconds + automaticCorrectionSeconds)
    + explicitSaves * saveSeconds
    + manualSeconds
    + tableSeconds;
  return {
    seconds, characters, periodicSaves, automaticCorrections,
    fixedOperations: explicitSaves + manualCorrections.length,
    tables: tables.length,
    tableSeconds
  };
}
function renderEstimate() {
  if (!input.value.trim()) {
    estimateTime.textContent = '—';
    estimateDetail.textContent = 'Nạp nội dung để tính theo settings.json';
    return;
  }
  if (!settings) {
    estimateTime.textContent = '…';
    estimateDetail.textContent = 'Đang đọc settings.json';
    return;
  }
  const result = estimateDocument(input.value);
  estimateTime.textContent = '≈ ' + formatDuration(result.seconds);
  estimateDetail.textContent = result.characters + ' ký tự · '
    + result.periodicSaves.toFixed(1) + ' lưu tự động · '
    + result.automaticCorrections.toFixed(1) + ' lỗi · '
    + result.fixedOperations + ' directive · '
    + result.tables + ' bảng (+' + Math.round(result.tableSeconds) + 's)';
}
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
  renderEstimate();
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
fetch('/api/settings')
  .then(response => {
    if (!response.ok) throw new Error('Không đọc được settings.json');
    return response.json();
  })
  .then(value => { settings = value; render(); })
  .catch(error => {
    estimateTime.textContent = 'Không tính được';
    estimateDetail.textContent = error.message;
  });
