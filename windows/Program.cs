using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

record Settings(double Wpm = 120, double ErrorRatePercent = 2.5, int CountdownSeconds = 5,
    bool IntentionalTypos = true, bool NaturalRhythm = true, bool HistoryEnabled = true,
    int HistoryMin = 150, int HistoryMax = 250, int ErrorMin = 40, int ErrorMax = 90,
    double SaveBefore = 5, double SaveView = 5, double SaveAfter = 5,
    int ErrorsMin = 2, int ErrorsMax = 3, int PhraseMin = 1, int PhraseMax = 3,
    double TelexProbability = .6, double SaveBeforeCorrectionProbability = .5);

static class Native {
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT point);
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public INPUTUNION data; }
    [StructLayout(LayoutKind.Explicit)] struct INPUTUNION {
        [FieldOffset(0)] public KEYBDINPUT keyboard;
        [FieldOffset(0)] public MOUSEINPUT mouse;
        [FieldOffset(0)] public HARDWAREINPUT hardware;
    }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort virtualKey, scan; public uint flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct HARDWAREINPUT { public uint message; public ushort low, high; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    const uint Keyboard = 1, Unicode = 4, KeyUp = 2;
    public const ushort Backspace = 0x08, Tab = 0x09, Enter = 0x0D, Escape = 0x1B,
        Control = 0x11, Shift = 0x10, Alt = 0x12, Slash = 0xBF, H = 0x48, T = 0x54, E = 0x45, Up = 0x26;

    public static bool StopRequested() {
        if ((GetAsyncKeyState(0x13) & 0x8000) != 0) return true;
        if ((GetAsyncKeyState(Escape) & 0x8000) != 0 && (GetAsyncKeyState(Control) & 0x8000) != 0 &&
            (GetAsyncKeyState(Alt) & 0x8000) != 0 && (GetAsyncKeyState(Shift) & 0x8000) != 0) return true;
        return GetCursorPos(out var point) && point.X <= 8 && point.Y <= 8;
    }
    public static void Text(string value) {
        foreach (var unit in value) Send(new INPUT { type = Keyboard, data = new INPUTUNION { keyboard = new KEYBDINPUT { scan = unit, flags = Unicode } } },
                                         new INPUT { type = Keyboard, data = new INPUTUNION { keyboard = new KEYBDINPUT { scan = unit, flags = Unicode | KeyUp } } });
    }
    static void Send(params INPUT[] inputs) {
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>()) != inputs.Length)
            throw new InvalidOperationException("Windows SendInput thất bại. Kiểm tra quyền của ứng dụng đích.");
    }
    static void Key(ushort key, bool up = false) => Send(new INPUT { type = Keyboard, data = new INPUTUNION { keyboard = new KEYBDINPUT { virtualKey = key, flags = up ? KeyUp : 0 } } });
    public static void Press(ushort key) { Key(key); Key(key, true); }
    public static void Shortcut(ushort key, params ushort[] modifiers) {
        foreach (var modifier in modifiers) Key(modifier);
        Press(key);
        foreach (var modifier in modifiers.Reverse()) Key(modifier, true);
    }
}

class Program {
    static Random Rng = new();
    static Settings settings = new();
    static ProgressOverlay? overlay;
    static double estimatedTotalSeconds;
    static int typed, total, sinceHistory, sinceError, nextHistory, nextError, errorsThisCycle, errorsTarget;
    static readonly Dictionary<char, string> Neighbours = new() {
        ['a']="qwsz",['b']="vghn",['c']="xdfv",['d']="serfcx",['e']="wsdr",['f']="drtgvc",['g']="ftyhbv",['h']="gyujnb",['i']="ujko",['j']="huikmn",['k']="jiolm",['l']="kop",['m']="njk",['n']="bhjm",['o']="iklp",['p']="ol",['q']="wa",['r']="edft",['s']="awedxz",['t']="rfgy",['u']="yhji",['v']="cfgb",['w']="qase",['x']="zsdc",['y']="tghu",['z']="asx" };
    static readonly Dictionary<char, string> Telex = new() {
        ['á']="as",['à']="af",['ả']="ar",['ã']="ax",['ạ']="aj",['ă']="aw",['ắ']="aws",['ằ']="awf",['ẳ']="awr",['ẵ']="awx",['ặ']="awj",
        ['â']="aa",['ấ']="aas",['ầ']="aaf",['ẩ']="aar",['ẫ']="aax",['ậ']="aaj",['é']="es",['è']="ef",['ẻ']="er",['ẽ']="ex",['ẹ']="ej",
        ['ê']="ee",['ế']="ees",['ề']="eef",['ể']="eer",['ễ']="eex",['ệ']="eej",['í']="is",['ì']="if",['ỉ']="ir",['ĩ']="ix",['ị']="ij",
        ['ó']="os",['ò']="of",['ỏ']="or",['õ']="ox",['ọ']="oj",['ô']="oo",['ố']="oos",['ồ']="oof",['ổ']="oor",['ỗ']="oox",['ộ']="ooj",
        ['ơ']="ow",['ớ']="ows",['ờ']="owf",['ở']="owr",['ỡ']="owx",['ợ']="owj",['ú']="us",['ù']="uf",['ủ']="ur",['ũ']="ux",['ụ']="uj",
        ['ư']="uw",['ứ']="uws",['ừ']="uwf",['ử']="uwr",['ữ']="uwx",['ự']="uwj",['ý']="ys",['ỳ']="yf",['ỷ']="yr",['ỹ']="yx",['ỵ']="yj" };

    [STAThread]
    static void Main(string[] args) {
        try { Run(args); }
        catch (Exception error) { Console.Error.WriteLine("Lỗi: " + error.Message); Environment.ExitCode = 1; }
    }

    static void Run(string[] args) {
        var root = FindProjectRoot();
        settings = LoadSettings(Path.Combine(root, "settings.json"));
        var parsed = ParseArguments(args, settings);
        settings = parsed.Settings;
        ValidateSettings(settings);
        if (parsed.Seed is int seed) Rng = new Random(seed);
        var file = FindInput(Path.Combine(root, "input"), parsed.FileName);
        var parts = InputDocument.Parse(File.ReadAllText(file));
        total = parts.Sum(CharacterCount);
        var estimate = Estimate(parts);
        estimatedTotalSeconds = estimate.TotalSeconds;
        Console.WriteLine($"Đã đọc {total} ký tự và {parts.Count(part => part is TablePart)} bảng từ {Path.GetFileName(file)}.");
        Console.WriteLine($"Ước tính {estimate.TotalSeconds:0.0} giây ({estimate:mm\\:ss}) ở {settings.Wpm:0.#} WPM.");
        if (parsed.DryRun) return;

        using var panel = overlay = new ProgressOverlay(total);
        for (var second = settings.CountdownSeconds; second > 0; second--) { panel.ShowCountdown(second, estimate); Console.Write($"Bắt đầu sau {second}…\r"); Thread.Sleep(1000); }
        var started = DateTime.Now;
        panel.Start(estimate);
        nextHistory = RandomBetween(settings.HistoryMin, settings.HistoryMax);
        nextError = RandomBetween(settings.ErrorMin, settings.ErrorMax);
        errorsTarget = RandomBetween(settings.ErrorsMin, settings.ErrorsMax);
        foreach (var part in parts) {
            EnsureRunning();
            switch (part) {
                case TextPart text: TypeText(text.Value); break;
                case SavePart: VisitHistory(); break;
                case CorrectionPart correction: CorrectManually(correction); break;
                case TablePart table: TypeTable(table); break;
            }
        }
        var actual = DateTime.Now - started;
        panel.Finish(typed, total, actual);
        Console.WriteLine($"\nHoàn tất: đã gõ {typed} ký tự trong {actual.TotalSeconds:0.0} giây.");
        Thread.Sleep(4000);
    }

    static void TypeText(string value) {
        var elements = TextElements(value);
        for (var index = 0; index < elements.Count;) {
            EnsureRunning();
            if (CanMakeAutomaticError(elements, index)) {
                var count = PhraseElementCount(elements, index, RandomBetween(settings.PhraseMin, settings.PhraseMax));
                var correct = string.Concat(elements.Skip(index).Take(count));
                var wrong = MutatePhrase(correct);
                if (wrong != correct) {
                    TypeCorrection(wrong, correct);
                    AddProgress(count);
                    index += count;
                    errorsThisCycle++;
                    sinceError = 0;
                    nextError = RandomBetween(settings.ErrorMin, settings.ErrorMax);
                    continue;
                }
            }
            TypeElement(elements[index]);
            AddProgress(1);
            index++;
            if (settings.HistoryEnabled && sinceHistory >= nextHistory) VisitHistory(force: false);
        }
    }

    static bool CanMakeAutomaticError(List<string> elements, int index) => settings.IntentionalTypos && settings.ErrorRatePercent > 0 &&
        sinceError >= nextError && errorsThisCycle < errorsTarget && elements[index].Any(char.IsLetterOrDigit);
    static int PhraseElementCount(List<string> elements, int start, int wantedWords) {
        var words = 0; var seenText = false; var count = 0;
        for (var i = start; i < elements.Count; i++) {
            count++; var current = elements[i];
            if (current.Any(char.IsLetterOrDigit)) seenText = true;
            if (seenText && (current.All(char.IsWhiteSpace) || i == elements.Count - 1)) { words++; seenText = false; if (words >= wantedWords) break; }
            if (current == "\n") break;
        }
        return Math.Max(1, count);
    }
    static string MutatePhrase(string phrase) => Regex.Replace(phrase, @"\p{L}+", match => MutateWord(match.Value));
    static string MutateWord(string word) {
        if (word.Length < 2) return word + word;
        if (Rng.NextDouble() < settings.TelexProbability && TelexTypo(word) is string telex) return telex;
        var index = Rng.Next(word.Length);
        return Rng.Next(4) switch {
            0 => word.Insert(index, word[index].ToString()),
            1 => word.Remove(index, 1),
            2 when index + 1 < word.Length => word[..index] + word[index + 1] + word[index] + word[(index + 2)..],
            _ when Neighbours.TryGetValue(char.ToLowerInvariant(word[index]), out var neighbours) => word[..index] + neighbours[Rng.Next(neighbours.Length)] + word[(index + 1)..],
            _ => word + word[^1]
        };
    }
    static string? TelexTypo(string value) {
        var changed = false; var result = new StringBuilder();
        foreach (var character in value) {
            var lower = char.ToLowerInvariant(character);
            if (!Telex.TryGetValue(lower, out var replacement)) { result.Append(character); continue; }
            result.Append(char.IsUpper(character) ? replacement.ToUpperInvariant() : replacement); changed = true;
        }
        return changed ? result.ToString() : null;
    }

    static void CorrectManually(CorrectionPart correction) { TypeCorrection(correction.Wrong, correction.Correct); AddProgress(TextElementCount(correction.Correct)); }
    static void TypeCorrection(string wrong, string correct) {
        overlay?.SetStatus("Đang xử lý lỗi");
        TypeRaw(wrong);
        var saveFirst = Rng.NextDouble() < settings.SaveBeforeCorrectionProbability;
        if (saveFirst) VisitHistory(false);
        for (var index = 0; index < TextElementCount(wrong); index++) { Native.Press(Native.Backspace); Sleep(.035); }
        if (!saveFirst) VisitHistory(false);
        TypeRaw(correct);
        overlay?.SetStatus("Đang gõ");
    }

    static void VisitHistory(bool resetCycle = true, bool force = true) {
        if (!force && !settings.HistoryEnabled) return;
        overlay?.SetStatus("Đang lưu lịch sử");
        Sleep(settings.SaveBefore);
        Native.Shortcut(Native.H, Native.Control, Native.Alt, Native.Shift);
        Sleep(settings.SaveView);
        Native.Press(Native.Escape);
        Sleep(settings.SaveAfter + .8);
        if (resetCycle) { sinceHistory = 0; errorsThisCycle = 0; errorsTarget = RandomBetween(settings.ErrorsMin, settings.ErrorsMax); nextHistory = RandomBetween(settings.HistoryMin, settings.HistoryMax); }
        overlay?.SetStatus("Đang gõ");
        UpdateOverlay(true);
    }

    static void TypeTable(TablePart table) {
        overlay?.SetStatus($"Đang tạo bảng {table.Rows}x{table.Columns}");
        ToolFinder("Chèn bảng", .55);
        for (var column = 2; column < table.Columns; column++) ToolFinder("Chèn cột bên phải");
        if (table.Columns == 1) ToolFinder("Xóa cột");
        for (var row = 2; row < table.Rows; row++) ToolFinder("Chèn hàng bên dưới");
        if (table.Rows == 1) ToolFinder("Xóa hàng");
        for (var row = 2; row < table.Rows; row++) { Native.Press(Native.Up); Sleep(.15); }
        foreach (var cell in table.Cells.Select((value, index) => (value, index))) {
            TypeText(cell.value);
            if (cell.index < table.Cells.Length - 1) { Native.Press(Native.Tab); Sleep(.25); }
        }
        Native.Shortcut(Native.T, Native.Control, Native.Alt, Native.Shift); Sleep(.12);
        Native.Shortcut(Native.E, Native.Control, Native.Alt, Native.Shift); Sleep(.55);
        overlay?.SetStatus("Đang gõ");
    }
    static void ToolFinder(string command, double settle = .35) { Native.Shortcut(Native.Slash, Native.Alt); Sleep(.25); Native.Text(command); Sleep(.35); Native.Press(Native.Enter); Sleep(settle); }

    static void TypeRaw(string value) { foreach (var element in TextElements(value)) TypeElement(element); }
    static void TypeElement(string element) {
        EnsureRunning();
        if (element == "\n") Native.Press(Native.Enter); else if (element == "\t") Native.Press(Native.Tab); else Native.Text(element);
        var delay = 60 / (settings.Wpm * 5);
        if (settings.NaturalRhythm) delay = delay * (.58 + Rng.NextDouble() * .9) + (element == " " ? .025 : 0) + (",;:".Contains(element) ? .18 : 0) + (".!?".Contains(element) ? .45 : 0) + (element == "\n" ? .65 : 0);
        Sleep(Math.Max(.012, delay));
    }
    static void AddProgress(int count) { typed += count; sinceHistory += count; sinceError += count; UpdateOverlay(); }
    static void UpdateOverlay(bool force = false) {
        var ratio = total == 0 ? 0 : Math.Max(0, total - typed) / (double)total;
        overlay?.Update(typed, total, TimeSpan.FromSeconds(estimatedTotalSeconds * ratio), force);
    }
    static void EnsureRunning() { if (Native.StopRequested()) throw new OperationCanceledException($"Đã dừng an toàn sau {typed}/{total} ký tự."); }
    static void Sleep(double seconds) { var until = DateTime.UtcNow.AddSeconds(seconds); while (DateTime.UtcNow < until) { EnsureRunning(); Thread.Sleep((int)Math.Min(50, Math.Max(1, (until - DateTime.UtcNow).TotalMilliseconds))); } }

    static int CharacterCount(DocumentPart part) => part switch { TextPart value => TextElementCount(value.Value), CorrectionPart value => TextElementCount(value.Correct), TablePart value => value.Cells.Sum(TextElementCount), _ => 0 };
    static TimeSpan Estimate(IEnumerable<DocumentPart> parts) {
        var list = parts.ToList(); var characters = list.Sum(CharacterCount); var save = settings.SaveBefore + settings.SaveView + settings.SaveAfter + .8;
        var periodic = settings.HistoryEnabled ? characters / Math.Max(1, (settings.HistoryMin + settings.HistoryMax) / 2.0) : 0;
        var errors = settings.IntentionalTypos ? characters / Math.Max(1, (settings.ErrorMin + settings.ErrorMax) / 2.0) : 0;
        var fixedSaves = list.Count(part => part is SavePart or CorrectionPart);
        var tables = list.OfType<TablePart>().Sum(table => table.Rows + table.Columns);
        return TimeSpan.FromSeconds(characters * 60 / Math.Max(1, settings.Wpm * 5) + (periodic + errors + fixedSaves) * save + tables);
    }
    static List<string> TextElements(string value) { var starts = StringInfo.ParseCombiningCharacters(value); return starts.Select((start, index) => value[start..(index + 1 < starts.Length ? starts[index + 1] : value.Length)]).ToList(); }
    static int TextElementCount(string value) => StringInfo.ParseCombiningCharacters(value).Length;
    static int RandomBetween(int min, int max) => Rng.Next(Math.Max(1, min), Math.Max(min, max) + 1);

    static Settings LoadSettings(string path) {
        if (!File.Exists(path)) return new(); using var document = JsonDocument.Parse(File.ReadAllText(path)); var root = document.RootElement;
        double Number(string name, double fallback) => root.TryGetProperty(name, out var value) && value.TryGetDouble(out var number) ? number : fallback;
        bool Flag(string name, bool fallback) => root.TryGetProperty(name, out var value) && value.ValueKind is JsonValueKind.True or JsonValueKind.False ? value.GetBoolean() : fallback;
        return new(Number("tocDoTuMoiPhut",120),Number("tyLeLoiPhanTram",2.5),(int)Number("demNguocGiay",5),Flag("batLoiCoY",true),Flag("batNhipTuNhien",true),Flag("batLuuLichSu",true),
            (int)Number("soKyTuLuuToiThieu",150),(int)Number("soKyTuLuuToiDa",250),(int)Number("khoangKyTuLoiToiThieu",40),(int)Number("khoangKyTuLoiToiDa",90),Number("choTruocLuuGiay",5),Number("xemLuuLichSuGiay",5),Number("choSauLuuGiay",5),
            (int)Number("soLoiMoiDotToiThieu",2),(int)Number("soLoiMoiDotToiDa",3),(int)Number("soTuCumSaiToiThieu",1),(int)Number("soTuCumSaiToiDa",3),Number("xacSuatLoiTelex",.6),Number("xacSuatLuuTruocKhiSua",.5));
    }
    static void ValidateSettings(Settings value) {
        if (value.Wpm is < 5 or > 1000 || value.CountdownSeconds is < 0 or > 60 || value.ErrorRatePercent is < 0 or > 30 ||
            value.HistoryMin < 1 || value.HistoryMax < value.HistoryMin || value.ErrorMin < 1 || value.ErrorMax < value.ErrorMin ||
            value.ErrorsMin < 1 || value.ErrorsMax < value.ErrorsMin || value.PhraseMin < 1 || value.PhraseMax < value.PhraseMin ||
            value.TelexProbability is < 0 or > 1 || value.SaveBeforeCorrectionProbability is < 0 or > 1 ||
            value.SaveBefore < 0 || value.SaveView < 0 || value.SaveAfter < 0)
            throw new ArgumentException("settings.json có giá trị ngoài phạm vi hoặc min lớn hơn max.");
    }
    record Arguments(string? FileName, bool DryRun, int? Seed, Settings Settings);
    static Arguments ParseArguments(string[] args, Settings value) {
        string? file = null; var dry = false; int? seed = null;
        for (var i = 0; i < args.Length; i++) switch (args[i]) {
            case "--dry-run": dry = true; break; case "--no-errors": value = value with { IntentionalTypos = false, ErrorRatePercent = 0 }; break; case "--no-history": value = value with { HistoryEnabled = false }; break;
            case "--wpm": value = value with { Wpm = double.Parse(args[++i], CultureInfo.InvariantCulture) }; break;
            case "--error-rate": value = value with { ErrorRatePercent = double.Parse(args[++i], CultureInfo.InvariantCulture), IntentionalTypos = true }; break;
            case "--countdown": value = value with { CountdownSeconds = int.Parse(args[++i], CultureInfo.InvariantCulture) }; break;
            case "--seed": seed = int.Parse(args[++i], CultureInfo.InvariantCulture); break; default: if (args[i].StartsWith('-')) throw new ArgumentException("Tùy chọn không hợp lệ: " + args[i]); file ??= args[i]; break;
        }
        if (value.Wpm is < 5 or > 1000 || value.CountdownSeconds is < 0 or > 60 || value.ErrorRatePercent is < 0 or > 30) throw new ArgumentException("Giá trị WPM, countdown hoặc error-rate ngoài phạm vi.");
        return new(file, dry, seed, value);
    }
    static string FindProjectRoot() { var candidates = new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory, Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..")) }; return candidates.FirstOrDefault(path => File.Exists(Path.Combine(path, "settings.json")) && Directory.Exists(Path.Combine(path, "input"))) ?? throw new DirectoryNotFoundException("Không tìm thấy settings.json và input/. Hãy chạy trong thư mục dự án."); }
    static string FindInput(string directory, string? requested) { var files = Directory.GetFiles(directory, "*.txt"); if (requested == null) return files.Length == 1 ? files[0] : throw new InvalidOperationException("Hãy chỉ định một file .txt trong input/."); var name = Path.GetFileNameWithoutExtension(requested); return files.FirstOrDefault(path => Path.GetFileNameWithoutExtension(path).Equals(name, StringComparison.OrdinalIgnoreCase)) ?? throw new FileNotFoundException("Không tìm thấy input/" + requested); }
}
