using System.Text.RegularExpressions;

abstract record DocumentPart;
record TextPart(string Value) : DocumentPart;
record SavePart : DocumentPart;
record CorrectionPart(string Wrong, string Correct) : DocumentPart;
record TablePart(int Rows, int Columns, string[] Cells) : DocumentPart;

static class InputDocument {
    static readonly Regex Directive = new(@"(?:\\?`)?\[([^,\]\n]+),\s*([^\]\n]+)\](?:\\?`)?|(?:\\?`)?\{save\}(?:\\?`)?", RegexOptions.Compiled);

    public static List<DocumentPart> Parse(string source) {
        source = ConvertMath(source.Replace("\r\n", "\n").Replace('\r', '\n'));
        var lines = source.Split('\n');
        var parts = new List<DocumentPart>();
        var plain = new List<string>();
        void Flush() {
            if (plain.Count == 0) return;
            ExpandDirectives(string.Join("\n", plain), parts);
            plain.Clear();
        }
        for (var index = 0; index < lines.Length; index++) {
            var match = Regex.Match(lines[index].Trim(), @"^\[\[TABLE\s+(\d+)x(\d+)\]\]$", RegexOptions.IgnoreCase);
            if (!match.Success) { plain.Add(lines[index]); continue; }
            Flush();
            var rows = int.Parse(match.Groups[1].Value);
            var columns = int.Parse(match.Groups[2].Value);
            if (rows is < 1 or > 20 || columns is < 1 or > 20) throw new InvalidDataException($"Bảng ở dòng {index + 1} phải từ 1x1 đến 20x20.");
            var cells = new List<string>();
            for (var row = 0; row < rows; row++) {
                if (++index >= lines.Length || lines[index].Trim() == "[[ENDTABLE]]") throw new InvalidDataException($"Bảng {rows}x{columns} thiếu dữ liệu.");
                var values = lines[index].Split('|').Select(value => value.Trim()).ToArray();
                if (values.Length != columns) throw new InvalidDataException($"Dòng {index + 1} cần đúng {columns} ô.");
                cells.AddRange(values);
            }
            if (++index >= lines.Length || lines[index].Trim() != "[[ENDTABLE]]") throw new InvalidDataException("Bảng thiếu [[ENDTABLE]].");
            parts.Add(new TablePart(rows, columns, cells.ToArray()));
        }
        Flush();
        return parts;
    }

    static void ExpandDirectives(string text, List<DocumentPart> parts) {
        var cursor = 0;
        foreach (Match match in Directive.Matches(text)) {
            if (match.Index > cursor) parts.Add(new TextPart(text[cursor..match.Index]));
            parts.Add(match.Groups[1].Success
                ? new CorrectionPart(match.Groups[1].Value.Trim(), match.Groups[2].Value.Trim())
                : new SavePart());
            cursor = match.Index + match.Length;
        }
        if (cursor < text.Length) parts.Add(new TextPart(text[cursor..]));
    }

    static string ConvertMath(string text) {
        text = Regex.Replace(text, @"\\\[([\s\S]*?)\\\]", m => ConvertMathBody(Regex.Replace(m.Groups[1].Value, @"\s+", " ").Trim()));
        return Regex.Replace(text, @"\\\(([\s\S]*?)\\\)", m => ConvertMathBody(m.Groups[1].Value));
    }

    static string ConvertMathBody(string value) {
        while (TryCommand(value, @"\frac", 2, out var fraction)) value = value[..fraction.Start] + $"({fraction.Groups[0]})/({fraction.Groups[1]})" + value[fraction.End..];
        while (TryCommand(value, @"\boxed", 1, out var boxed)) value = value[..boxed.Start] + boxed.Groups[0] + value[boxed.End..];
        value = Regex.Replace(value, @"\\frac\s*([A-Za-z0-9])\s*([A-Za-z0-9])", "$1/$2");
        value = Regex.Replace(value, @"\\text\{([^{}]*)\}", "$1");
        value = Regex.Replace(value, @"_\{([^{}]+)\}", m => ToSubscript(m.Groups[1].Value));
        var replacements = new (string From, string To)[] {
            (@"\leftrightarrow","↔"),(@"\Rightarrow","→"),(@"\Leftarrow","←"),(@"\rightarrow","→"),(@"\leftarrow","←"),
            (@"\subseteq","⊆"),(@"\supseteq","⊇"),(@"\langle","⟨"),(@"\rangle","⟩"),(@"\notin","∉"),(@"\infty","∞"),(@"\forall","∀"),(@"\exists","∃"),
            (@"\times","×"),(@"\approx","≈"),(@"\cdot","·"),(@"\neq","≠"),(@"\leq","≤"),(@"\geq","≥"),
            (@"\le","≤"),(@"\ge","≥"),(@"\in","∈"),(@"\cup","∪"),(@"\cap","∩"),(@"\to","→"),(@"\mid"," | "),
            (@"\ln","ln"),(@"\;",""),(@"\,",""),(@"\!",""),(@"\ ",""),(@"\{","{"),(@"\}","}"),("{,}",",")
        };
        foreach (var item in replacements) value = value.Replace(item.From, item.To);
        value = Regex.Replace(value, @"_([0-9ijn])", m => ToSubscript(m.Groups[1].Value));
        return value;
    }

    static string ToSubscript(string value) {
        const string normal = "0123456789ijn+-=()";
        const string lower = "₀₁₂₃₄₅₆₇₈₉ᵢⱼₙ₊₋₌₍₎";
        return string.Concat(value.Select(c => normal.IndexOf(c) is var i && i >= 0 ? lower[i] : c));
    }

    record CommandMatch(int Start, int End, string[] Groups);
    static bool TryCommand(string value, string command, int count, out CommandMatch result) {
        var start = value.IndexOf(command, StringComparison.Ordinal);
        if (start < 0) { result = null!; return false; }
        var cursor = start + command.Length;
        var groups = new List<string>();
        for (var group = 0; group < count; group++) {
            while (cursor < value.Length && char.IsWhiteSpace(value[cursor])) cursor++;
            if (cursor >= value.Length || value[cursor] != '{') { result = null!; return false; }
            var depth = 0; var content = ++cursor;
            while (cursor < value.Length) {
                if (value[cursor] == '{') depth++;
                if (value[cursor] == '}' && depth-- == 0) break;
                cursor++;
            }
            if (cursor >= value.Length) { result = null!; return false; }
            groups.Add(value[content..cursor]); cursor++;
        }
        result = new CommandMatch(start, cursor, groups.ToArray()); return true;
    }
}
