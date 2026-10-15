using System.Drawing;
using System.Windows.Forms;

sealed class ProgressOverlay : IDisposable {
    readonly Thread thread;
    Form? form;
    Label? status;
    Label? remaining;
    Label? elapsed;
    Label? detail;
    ProgressBar? bar;
    DateTime started;
    readonly ManualResetEventSlim ready = new(false);

    public ProgressOverlay(int total) {
        thread = new Thread(() => Run(total)) { IsBackground = true };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        ready.Wait();
    }

    void Run(int total) {
        form = new Form {
            FormBorderStyle = FormBorderStyle.None, ShowInTaskbar = false, TopMost = true,
            BackColor = Color.FromArgb(18, 20, 24), ClientSize = new Size(430, 184),
            StartPosition = FormStartPosition.Manual, Opacity = .97
        };
        var screen = Screen.PrimaryScreen!.WorkingArea;
        form.Location = new Point(screen.Right - form.Width - 18, screen.Top + 18);
        status = TextLabel("HUMANTYPER", 11, Color.FromArgb(89, 220, 242), true);
        remaining = TextLabel("Còn ≈ 00:00", 23, Color.White, true);
        elapsed = TextLabel("Đã chạy 00:00", 12, Color.Gainsboro, true);
        detail = TextLabel("0 ký tự còn lại  •  0% hoàn thành", 11, Color.FromArgb(185, 192, 204));
        bar = new ProgressBar { Minimum = 0, Maximum = Math.Max(1, total), Value = 0, Style = ProgressBarStyle.Continuous, Dock = DockStyle.Bottom, Height = 7 };
        form.Controls.AddRange(new Control[] { status, remaining, elapsed, detail, bar });
        status.SetBounds(22, 18, 350, 22); remaining.SetBounds(22, 48, 390, 34); elapsed.SetBounds(22, 91, 200, 22); detail.SetBounds(22, 118, 390, 22); bar.SetBounds(22, 154, 386, 7);
        form.CreateControl();
        var timer = new System.Windows.Forms.Timer { Interval = 1000 };
        timer.Tick += (_, _) => { if (!form.IsDisposed && started != default) elapsed!.Text = $"Đã chạy {Format(DateTime.Now - started)}"; };
        timer.Start();
        ready.Set();
        Application.Run(form);
    }

    static Label TextLabel(string text, float size, Color color, bool bold = false) => new() { Text = text, ForeColor = color, BackColor = Color.Transparent, Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular), AutoSize = false };
    static string Format(TimeSpan value) => value.TotalHours >= 1 ? value.ToString(@"h\:mm\:ss") : value.ToString(@"mm\:ss");
    void Invoke(Action action) { if (form is { IsDisposed: false }) form.BeginInvoke(action); }
    public void Start(TimeSpan estimate) { started = DateTime.Now; Invoke(() => { remaining!.Text = $"Còn ≈ {Format(estimate)}"; form!.Show(); }); }
    public void Update(int typed, int total, TimeSpan estimate) => Invoke(() => { remaining!.Text = $"Còn ≈ {Format(estimate)}"; detail!.Text = $"{Math.Max(0, total - typed)} ký tự còn lại  •  {(total == 0 ? 100 : typed * 100 / total)}% hoàn thành"; bar!.Value = Math.Min(bar.Maximum, Math.Max(0, typed)); });
    public void Finish(int typed, int total, TimeSpan actual) => Invoke(() => { remaining!.Text = $"Tổng {Format(actual)}"; elapsed!.Text = "Hoàn tất"; detail!.Text = $"{typed} ký tự  •  100% hoàn thành"; bar!.Value = bar.Maximum; });
    public void Close() { Invoke(() => form!.Close()); }
    public void Dispose() { Close(); ready.Dispose(); }
}
