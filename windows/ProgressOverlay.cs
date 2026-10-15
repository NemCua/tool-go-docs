using System.Drawing;
using System.Windows.Forms;

sealed class ProgressOverlay : IDisposable {
    sealed class NoActivateForm : Form {
        protected override bool ShowWithoutActivation => true;
        protected override CreateParams CreateParams { get { var value = base.CreateParams; value.ExStyle |= 0x08000000 | 0x00000080; return value; } }
    }

    readonly Form form;
    readonly Label status;
    readonly Label remaining;
    readonly Label elapsed;
    readonly Label detail;
    readonly ProgressBar bar;
    DateTime started;
    DateTime lastDraw = DateTime.MinValue;

    public ProgressOverlay(int total) {
        form = new NoActivateForm { FormBorderStyle = FormBorderStyle.None, ShowInTaskbar = false, TopMost = true, BackColor = Color.FromArgb(18, 20, 24), ClientSize = new Size(430, 184), StartPosition = FormStartPosition.Manual, Opacity = .97 };
        var screen = Screen.FromPoint(Cursor.Position).WorkingArea;
        form.Location = new Point(screen.Right - form.Width - 18, screen.Top + 18);
        status = Label("HUMANTYPER", 11, Color.FromArgb(89, 220, 242), true);
        remaining = Label("Còn ≈ 00:00", 23, Color.White, true);
        elapsed = Label("Đã chạy 00:00", 12, Color.Gainsboro, true);
        detail = Label("0 ký tự còn lại  •  0% hoàn thành", 11, Color.FromArgb(185, 192, 204));
        bar = new ProgressBar { Minimum = 0, Maximum = Math.Max(1, total), Value = 0, Style = ProgressBarStyle.Continuous, Height = 7 };
        form.Controls.AddRange(new Control[] { status, remaining, elapsed, detail, bar });
        status.SetBounds(22, 18, 350, 22); remaining.SetBounds(22, 48, 390, 34); elapsed.SetBounds(22, 91, 300, 22); detail.SetBounds(22, 118, 390, 22); bar.SetBounds(22, 154, 386, 7);
    }

    static Label Label(string text, float size, Color color, bool bold = false) => new() { Text = text, ForeColor = color, BackColor = Color.Transparent, Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular), AutoSize = false };
    static string Format(TimeSpan value) => value.TotalHours >= 1 ? value.ToString(@"h\:mm\:ss") : value.ToString(@"mm\:ss");
    void Visible() { if (!form.Visible) form.Show(); }
    public void Start(TimeSpan estimate) { started = DateTime.Now; remaining.Text = $"Còn ≈ {Format(estimate)}"; Visible(); Pump(); }
    public void ShowCountdown(int seconds, TimeSpan estimate) { remaining.Text = $"Bắt đầu sau {seconds}"; elapsed.Text = $"Ước tính {Format(estimate)}"; Visible(); Pump(); }
    public void SetStatus(string value) { status.Text = value.ToUpperInvariant(); Pump(); }
    public void Update(int typed, int total, TimeSpan estimate, bool force = false) {
        var now = DateTime.UtcNow;
        if (!force && now - lastDraw < TimeSpan.FromSeconds(2)) { Pump(); return; }
        lastDraw = now;
        remaining.Text = $"Còn ≈ {Format(estimate)}";
        elapsed.Text = started == default ? elapsed.Text : $"Đã chạy {Format(DateTime.Now - started)}";
        detail.Text = $"{Math.Max(0, total - typed)} ký tự còn lại  •  {(total == 0 ? 100 : typed * 100 / total)}% hoàn thành";
        bar.Value = Math.Min(bar.Maximum, Math.Max(0, typed));
        Pump();
    }
    public void Finish(int typed, int total, TimeSpan actual) { remaining.Text = $"Tổng {Format(actual)}"; elapsed.Text = "Hoàn tất"; detail.Text = $"{typed} ký tự  •  100% hoàn thành"; bar.Value = bar.Maximum; Pump(); }
    static void Pump() => Application.DoEvents();
    public void Close() { if (!form.IsDisposed) { form.Close(); form.Dispose(); } }
    public void Dispose() => Close();
}
