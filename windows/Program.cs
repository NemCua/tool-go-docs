using System.Runtime.InteropServices;
using System.Text.Json;

record Settings(double Wpm = 120, double ErrorRatePercent = 2.5, int CountdownSeconds = 5,
    bool IntentionalTypos = true, bool NaturalRhythm = true, bool HistoryEnabled = true);

static class Native {
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] p, int size);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    const uint INPUT_KEYBOARD = 1, KEYEVENTF_UNICODE = 4, KEYEVENTF_KEYUP = 2;
    const uint KEYEVENTF_SCANCODE = 8;
    public static bool StopRequested() {
        // Pause/break is the emergency key; Ctrl+Alt+Shift+Esc is also accepted.
        if ((GetAsyncKeyState(0x13) & 0x8000) != 0) return true;
        if ((GetAsyncKeyState(0x1B) & 0x8000) != 0 && (GetAsyncKeyState(0x11) & 0x8000) != 0 &&
            (GetAsyncKeyState(0x12) & 0x8000) != 0 && (GetAsyncKeyState(0x10) & 0x8000) != 0) return true;
        return GetCursorPos(out var p) && p.X <= 8 && p.Y <= 8;
    }
    public static void Text(string value) {
        foreach (var rune in value.EnumerateRunes()) {
            var code = (ushort)rune.Value;
            var input = new[] {
                new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wScan = code, dwFlags = KEYEVENTF_UNICODE } },
                new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wScan = code, dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP } }
            };
            SendInput(2, input, Marshal.SizeOf<INPUT>());
        }
    }
    static void Key(ushort vk, bool up = false) {
        var input = new[] { new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = vk, dwFlags = up ? KEYEVENTF_KEYUP : 0 } } };
        SendInput(1, input, Marshal.SizeOf<INPUT>());
    }
    public static void Press(ushort vk) { Key(vk); Key(vk, true); }
    public static void Shortcut(ushort key, params ushort[] modifiers) {
        foreach (var m in modifiers) Key(m);
        Press(key);
        foreach (var m in modifiers.Reverse()) Key(m, true);
    }
}

class Program {
    static readonly Random Rng = new();
    static readonly Dictionary<char, string> Neighbours = new() {
        ['a']="qwsz",['b']="vghn",['c']="xdfv",['d']="serfcx",['e']="wsdr",['f']="drtgvc",['g']="ftyhbv",['h']="gyujnb",['i']="ujko",['j']="huikmn",['k']="jiolm",['l']="kop",['m']="njk",['n']="bhjm",['o']="iklp",['p']="ol",['q']="wa",['r']="edft",['s']="awedxz",['t']="rfgy",['u']="yhji",['v']="cfgb",['w']="qase",['x']="zsdc",['y']="tghu",['z']="asx" };
    static Settings LoadSettings(string path) {
        if (!File.Exists(path)) return new();
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var root = document.RootElement;
        double Number(string name, double fallback) => root.TryGetProperty(name, out var p) && p.TryGetDouble(out var n) ? n : fallback;
        bool Flag(string name, bool fallback) => root.TryGetProperty(name, out var p) && (p.ValueKind is JsonValueKind.True or JsonValueKind.False) ? p.GetBoolean() : fallback;
        return new(
            Wpm: Number("tocDoTuMoiPhut", 120),
            ErrorRatePercent: Number("tyLeLoiPhanTram", 2.5),
            CountdownSeconds: (int)Number("demNguocGiay", 5),
            IntentionalTypos: Flag("batLoiCoY", true),
            NaturalRhythm: Flag("batNhipTuNhien", true),
            HistoryEnabled: Flag("batLuuLichSu", true));
    }
    static void Main(string[] args) {
        var projectRoot = Directory.GetCurrentDirectory();
        var input = Path.Combine(projectRoot, "input");
        var settingsPath = Path.Combine(projectRoot, "settings.json");
        var settings = LoadSettings(settingsPath);
        var requested = args.FirstOrDefault(a => !a.StartsWith('-'));
        var dryRun = args.Contains("--dry-run");
        if (args.Contains("--no-errors")) settings = settings with { ErrorRatePercent = 0, IntentionalTypos = false };
        if (args.Contains("--no-history")) { /* Windows version does not automate version history. */ }
        if (!Directory.Exists(input)) Fail($"Không tìm thấy thư mục input/: {input}");
        var files = Directory.GetFiles(input, "*.txt");
        var file = requested == null ? files.SingleOrDefault() : files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f).Equals(requested, StringComparison.OrdinalIgnoreCase));
        if (file == null) Fail("Hãy chỉ định một file .txt trong input/.");
        var text = File.ReadAllText(file!);
        Console.WriteLine($"Đã đọc {text.Length} ký tự từ {Path.GetFileName(file)}.");
        if (dryRun) { Console.WriteLine($"Ước tính {text.Length / (settings.Wpm * 5) * 60:0.0} giây."); return; }
        for (var i = settings.CountdownSeconds; i > 0; i--) { Console.Write($"Bắt đầu sau {i}…\r"); Thread.Sleep(1000); }
        var delay = 60000 / (settings.Wpm * 5);
        foreach (var c in text) {
            if (Native.StopRequested()) { Console.WriteLine("\nĐã dừng khẩn cấp."); return; }
            if (c == '\n') { Native.Press(0x0D); Thread.Sleep(80); continue; }
            if (c == '\t') { Native.Press(0x09); Thread.Sleep(80); continue; }
            var output = c;
            if (settings.IntentionalTypos && Rng.NextDouble() < settings.ErrorRatePercent / 100 && Neighbours.TryGetValue(char.ToLower(c), out var n)) output = char.IsUpper(c) ? char.ToUpper(n[Rng.Next(n.Length)]) : n[Rng.Next(n.Length)];
            Native.Text(output.ToString());
            var wait = settings.NaturalRhythm
                ? delay * (0.58 + Rng.NextDouble() * .9) + (c is ' ' ? 25 : 0)
                : delay;
            Thread.Sleep(Math.Max(12, (int)wait));
        }
        Console.WriteLine("\nHoàn tất.");
    }
    static void Fail(string message) { Console.Error.WriteLine("Lỗi: " + message); Environment.Exit(1); }
}
