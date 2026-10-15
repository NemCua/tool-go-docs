import ApplicationServices
import AppKit
import Foundation

private var stopRequested = false
private var progressOverlay: ProgressOverlay?
private let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
private let generatedEventMarker: Int64 = 0x48545950 // "HTYP"
private let emergencyStopModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

struct Config {
    var fileName: String?
    var wpm: Double = 120
    var errorRate: Double = 0.025
    var countdown: Int = 5
    var dryRun = false
    var tableOnly = false
    var positionOnly = false
    var longPauses = true
    var visitHistoryDuringPauses = true
    var historyMinCharacters = 180
    var historyMaxCharacters = 300
    var waitBeforeHistory = 5.0
    var historyViewTime = 5.0
    var waitAfterHistory = 5.0
    var typoMinCharacters = 80
    var typoMaxCharacters = 160
    var typosMinPerHistory = 1
    var typosMaxPerHistory = 3
    var telexTypoProbability = 0.75
    var historyBeforeCorrectionProbability = 0.5
    var typoPhraseMinWords = 1
    var typoPhraseMaxWords = 3
    var naturalRhythm = true
    var seed: UInt64?
}

// A non-activating panel keeps Google Docs focused while HumanTyper shows
// progress. It deliberately has no mouse controls: the keyboard emergency
// shortcuts remain reliable while events are being sent to Google Docs.
private final class ProgressOverlay: NSObject {
    private let panel: NSPanel
    private let eyebrowLabel = NSTextField(labelWithString: "HUMANTYPER")
    private let statusLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "Đã chạy 00:00")
    private let progressFill = NSView()
    private var progressWidth: NSLayoutConstraint!
    private let total: Int
    private let estimateRemaining: (Int) -> Double
    private var lastDraw = Date.distantPast
    private var lastStatus = ""
    private var startedAt: Date?
    private var elapsedTimer: Timer?

    init(total: Int, estimateRemaining: @escaping (Int) -> Double) {
        self.total = total
        self.estimateRemaining = estimateRemaining
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true

        let content = NSVisualEffectView()
        content.material = .hudWindow
        content.blendingMode = .behindWindow
        content.state = .active
        content.appearance = NSAppearance(named: .darkAqua)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.018, alpha: 0.95).cgColor
        content.layer?.cornerRadius = 20
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        panel.contentView = content

        let accent = NSView()
        accent.wantsLayer = true
        accent.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.95, alpha: 1).cgColor
        accent.layer?.cornerRadius = 2
        eyebrowLabel.font = .systemFont(ofSize: 10, weight: .bold)
        eyebrowLabel.textColor = NSColor(calibratedRed: 0.36, green: 0.86, blue: 0.96, alpha: 1)
        statusLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.wantsLayer = true
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 27, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.alignment = .right
        detailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.64)
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        elapsedLabel.textColor = NSColor.white.withAlphaComponent(0.82)

        let progressTrack = NSView()
        progressTrack.wantsLayer = true
        progressTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        progressTrack.layer?.cornerRadius = 3
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.95, alpha: 1).cgColor
        progressFill.layer?.cornerRadius = 3

        for view in [accent, eyebrowLabel, statusLabel, timeLabel, detailLabel, elapsedLabel, progressTrack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        progressWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            accent.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            accent.widthAnchor.constraint(equalToConstant: 4),
            accent.heightAnchor.constraint(equalToConstant: 24),
            eyebrowLabel.leadingAnchor.constraint(equalTo: accent.trailingAnchor, constant: 9),
            eyebrowLabel.centerYAnchor.constraint(equalTo: accent.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            statusLabel.topAnchor.constraint(equalTo: accent.bottomAnchor, constant: 13),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            timeLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 9),
            timeLabel.widthAnchor.constraint(equalToConstant: 180),
            detailLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 14),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
            detailLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            elapsedLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            elapsedLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 10),
            progressTrack.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
            progressTrack.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 14),
            progressTrack.heightAnchor.constraint(equalToConstant: 6),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressWidth
        ])
    }

    func show(status: String, typed: Int = 0) {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 18, y: screen.maxY - size.height - 18))
        update(status: status, typed: typed, force: true)
        panel.orderFrontRegardless()
    }

    func showCountdown(_ second: Int) {
        update(status: "Bắt đầu sau \(second)", typed: 0, force: true)
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.12
        pulse.toValue = 1
        pulse.duration = 0.42
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        statusLabel.layer?.add(pulse, forKey: "countdownPulse")
    }

    func update(status: String, typed: Int, force: Bool = false) {
        guard panel.isVisible else { return }
        let now = Date()
        // This is an estimate recalculated from remaining work, not a
        // countdown. Drawing at most once every two seconds avoids UI work in
        // the per-character typing loop.
        guard force || status != lastStatus || now.timeIntervalSince(lastDraw) >= 2 else { return }
        lastDraw = now
        lastStatus = status
        let remaining = max(0, total - typed)
        let progress = total == 0 ? 1 : min(1, max(0, Double(typed) / Double(total)))
        statusLabel.stringValue = status
        timeLabel.stringValue = "Còn ≈ \(format(seconds: estimateRemaining(typed)))"
        detailLabel.stringValue = "\(remaining) ký tự còn lại  •  \(Int((progress * 100).rounded()))% hoàn thành"
        progressWidth.constant = 394 * progress
    }

    func startElapsed() {
        elapsedTimer?.invalidate()
        startedAt = Date()
        updateElapsed()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
        elapsedTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    @discardableResult
    func finish(typed: Int) -> Double {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        statusLabel.stringValue = "Hoàn tất"
        timeLabel.stringValue = "Tổng \(format(seconds: elapsed))"
        elapsedLabel.stringValue = "Thời gian thực từ lúc bắt đầu gõ"
        detailLabel.stringValue = "0 ký tự còn lại  •  100% hoàn thành"
        progressWidth.constant = 394
        return elapsed
    }

    func close() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        panel.orderOut(nil)
    }

    private func updateElapsed() {
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        elapsedLabel.stringValue = "Đã chạy \(format(seconds: elapsed))"
    }

    private func format(seconds: Double) -> String {
        let rounded = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", rounded / 60, rounded % 60)
    }
}

struct RNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func between(_ low: Double, _ high: Double) -> Double {
        low + (high - low) * unit()
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}

private let neighbours: [Character: [Character]] = [
    "a": Array("qwsz"), "b": Array("vghn"), "c": Array("xdfv"),
    "d": Array("serfcx"), "e": Array("wsdr"), "f": Array("drtgvc"),
    "g": Array("ftyhbv"), "h": Array("gyujnb"), "i": Array("ujko"),
    "j": Array("huikmn"), "k": Array("jiolm"), "l": Array("kop"),
    "m": Array("njk"), "n": Array("bhjm"), "o": Array("iklp"),
    "p": Array("ol"), "q": Array("wa"), "r": Array("edft"),
    "s": Array("awedxz"), "t": Array("rfgy"), "u": Array("yhji"),
    "v": Array("cfgb"), "w": Array("qase"), "x": Array("zsdc"),
    "y": Array("tghu"), "z": Array("asx")
]

private func usage() -> Never {
    let text = """
    HumanTyper — mô phỏng nhịp đánh máy trên macOS

    Cách dùng:
      ./human-typer [TÊN_FILE] [--wpm 120] [--error-rate 2.5] [--countdown 15]

    Tuỳ chọn:
      --wpm N          Tốc độ trung bình, mặc định 120
      --error-rate N   Phần trăm khả năng gõ sai chữ ASCII, mặc định 2.5
      --countdown N    Số giây chờ để chuyển sang cửa sổ đích, mặc định 15
      --seed N         Cố định chuỗi ngẫu nhiên để chạy lặp lại
      --no-errors      Không cố ý gõ sai
      --no-history     Không tự mở lịch sử phiên bản và nghỉ dài
      --dry-run        Chỉ đọc và thống kê file, không gửi phím
      --table-only     Chỉ tạo bảng rồi dừng để kiểm tra vị trí focus
      --position-only  Tạo bảng, nhấn Lên để về hàng đầu rồi dừng
      -h, --help       Hiện trợ giúp

    Để dừng: nhấn phím `, Control + Option + Command + Escape, hoặc đưa chuột vào góc trên-trái.
    """
    print(text)
    exit(0)
}

private func fail(_ message: String) -> Never {
    fputs("Lỗi: \(message)\n", stderr)
    exit(1)
}

private func loadSettings(into config: inout Config) {
    let base = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
    let local = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("settings.json")
    let url = FileManager.default.fileExists(atPath: local.path) ? local : base.appendingPathComponent("settings.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fail("settings.json không phải JSON hợp lệ")
    }
    if let n = json["tocDoTuMoiPhut"] as? Double { config.wpm = n }
    if let n = json["tyLeLoiPhanTram"] as? Double { config.errorRate = n / 100 }
    if let n = json["demNguocGiay"] as? Int { config.countdown = n }
    if let n = json["batLoiCoY"] as? Bool, !n { config.errorRate = 0 }
    if let n = json["batLuuLichSu"] as? Bool { config.visitHistoryDuringPauses = n }
    if let n = json["soKyTuLuuToiThieu"] as? Int { config.historyMinCharacters = n }
    if let n = json["soKyTuLuuToiDa"] as? Int { config.historyMaxCharacters = n }
    if let n = json["choTruocLuuGiay"] as? Double { config.waitBeforeHistory = n }
    if let n = json["xemLuuLichSuGiay"] as? Double { config.historyViewTime = n }
    if let n = json["choSauLuuGiay"] as? Double { config.waitAfterHistory = n }
    if let n = json["khoangKyTuLoiToiThieu"] as? Int { config.typoMinCharacters = n }
    if let n = json["khoangKyTuLoiToiDa"] as? Int { config.typoMaxCharacters = n }
    if let n = json["soLoiMoiDotToiThieu"] as? Int { config.typosMinPerHistory = n }
    if let n = json["soLoiMoiDotToiDa"] as? Int { config.typosMaxPerHistory = n }
    if let n = json["xacSuatLoiTelex"] as? Double { config.telexTypoProbability = n }
    if let n = json["xacSuatLuuTruocKhiSua"] as? Double { config.historyBeforeCorrectionProbability = n }
    if let n = json["soTuCumSaiToiThieu"] as? Int { config.typoPhraseMinWords = n }
    if let n = json["soTuCumSaiToiDa"] as? Int { config.typoPhraseMaxWords = n }
    if let n = json["batNhipTuNhien"] as? Bool { config.naturalRhythm = n }
    guard config.wpm >= 5, config.wpm <= 1000, config.errorRate >= 0, config.errorRate <= 0.3,
          config.countdown >= 0, config.countdown <= 60, config.historyMinCharacters >= 1,
          config.historyMaxCharacters >= config.historyMinCharacters, config.waitBeforeHistory >= 0,
          config.historyViewTime >= 0, config.waitAfterHistory >= 0, config.typoMinCharacters >= 1,
          config.typoMaxCharacters >= config.typoMinCharacters, config.typosMinPerHistory >= 0,
          config.typosMaxPerHistory >= config.typosMinPerHistory, config.telexTypoProbability >= 0,
          config.telexTypoProbability <= 1, config.historyBeforeCorrectionProbability >= 0,
          config.historyBeforeCorrectionProbability <= 1, config.typoPhraseMinWords >= 1,
          config.typoPhraseMaxWords >= config.typoPhraseMinWords else {
        fail("một hoặc nhiều giá trị trong settings.json nằm ngoài phạm vi hợp lệ")
    }
}

private func parseArguments() -> Config {
    var config = Config()
    loadSettings(into: &config)
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-h", "--help": usage()
        case "--no-errors": config.errorRate = 0
        case "--no-long-pauses": config.longPauses = false
        case "--no-history": config.visitHistoryDuringPauses = false
        case "--dry-run": config.dryRun = true
        case "--table-only": config.tableOnly = true
        case "--position-only": config.positionOnly = true
        case "--wpm", "--error-rate", "--countdown", "--seed":
            guard i + 1 < args.count else { fail("thiếu giá trị sau \(arg)") }
            i += 1
            let value = args[i]
            switch arg {
            case "--wpm":
                guard let n = Double(value), n >= 5, n <= 1000 else { fail("--wpm phải từ 5 đến 1000") }
                config.wpm = n
            case "--error-rate":
                guard let n = Double(value), n >= 0, n <= 30 else { fail("--error-rate phải từ 0 đến 30") }
                config.errorRate = n / 100
            case "--countdown":
                guard let n = Int(value), n >= 0, n <= 60 else { fail("--countdown phải từ 0 đến 60") }
                config.countdown = n
            default:
                guard let n = UInt64(value) else { fail("--seed phải là số nguyên không âm") }
                config.seed = n
            }
        default:
            if arg.hasPrefix("-") { fail("tuỳ chọn không hợp lệ: \(arg)") }
            if config.fileName != nil { fail("chỉ được chọn một file .txt") }
            config.fileName = arg
        }
        i += 1
    }
    return config
}

private func findInputFile(named requestedName: String?) -> URL {
    let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
        .standardizedFileURL.deletingLastPathComponent()
    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let localInput = currentDirectory.appendingPathComponent("input", isDirectory: true)
    let adjacentInput = executableDirectory.appendingPathComponent("input", isDirectory: true)
    let directory = FileManager.default.fileExists(atPath: localInput.path) ? localInput : adjacentInput

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        fail("không tìm thấy thư mục input/")
    }

    let files: [URL]
    do {
        files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            guard url.pathExtension.lowercased() == "txt" else { return false }
            return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    } catch {
        fail("không đọc được thư mục input/")
    }

    if let requestedName {
        guard URL(fileURLWithPath: requestedName).lastPathComponent == requestedName else { fail("tên file không được chứa đường dẫn") }
        let wanted = requestedName.lowercased().hasSuffix(".txt") ? requestedName : requestedName + ".txt"
        guard let match = files.first(where: { $0.lastPathComponent == wanted }) else { fail("không tìm thấy input/\(wanted)") }
        return match
    }
    guard files.count == 1 else {
        if files.isEmpty { fail("input/ phải chứa đúng một file .txt, hiện chưa có file nào") }
        fail("input/ phải chứa đúng một file .txt, hiện có \(files.count) file")
    }
    return files[0]
}

private func postKey(code: CGKeyCode) {
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    // Never inherit modifier state from the preceding Google Docs shortcut.
    down?.flags = []
    up?.flags = []
    down?.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    up?.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

private func postShortcut(code: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    down?.flags = flags
    up?.flags = flags
    down?.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    up?.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

private func postText(_ text: String) {
    if text == "\n" {
        postKey(code: 36)
        return
    }
    if text == "\t" {
        postKey(code: 48)
        return
    }
    let source = CGEventSource(stateID: .hidSystemState)
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
    let utf16 = Array(text.utf16)
    utf16.withUnsafeBufferPointer { buffer in
        guard let address = buffer.baseAddress else { return }
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: address)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: address)
    }
    down.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    up.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

private func pumpEvents(for seconds: Double) {
    let deadline = Date().addingTimeInterval(seconds)
    repeat {
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 || stopRequested { break }
        CFRunLoopRunInMode(.defaultMode, min(remaining, 0.025), true)
    } while !stopRequested
}

private func installSafetyMonitor() -> CFMachPort? {
    let monitoredTypes: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged]
    let mask = monitoredTypes.reduce(CGEventMask(0)) { result, type in
        result | CGEventMask(1 << type.rawValue)
    }
    let callback: CGEventTapCallBack = { _, type, event, _ in
        let generatedByTool = event.getIntegerValueField(.eventSourceUserData) == generatedEventMarker
        if type == .keyDown && !generatedByTool {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let pressed = event.flags.intersection(emergencyStopModifiers)
            if keyCode == 50 || (keyCode == 53 && pressed == emergencyStopModifiers) {
                stopRequested = true
                return nil
            }
        }
        if !generatedByTool && (type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged) {
            let point = event.location
            if point.x <= mainDisplayBounds.minX + 8 && point.y <= mainDisplayBounds.minY + 8 {
                stopRequested = true
            }
        }
        return Unmanaged.passUnretained(event)
    }
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    ) else { return nil }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return tap
}

private func typo(for character: Character, rng: inout RNG) -> Character? {
    let lower = Character(String(character).lowercased())
    guard let choices = neighbours[lower], !choices.isEmpty else { return nil }
    var chosen = choices[rng.int(0...(choices.count - 1))]
    if character.isUppercase { chosen = Character(String(chosen).uppercased()) }
    return chosen
}

private let telexMisspellings: [Character: String] = [
    "á": "as", "à": "af", "ả": "ar", "ã": "ax", "ạ": "aj",
    "ă": "aw", "ắ": "aws", "ằ": "awf", "ẳ": "awr", "ẵ": "awx", "ặ": "awj",
    "â": "aa", "ấ": "aas", "ầ": "aaf", "ẩ": "aar", "ẫ": "aax", "ậ": "aaj",
    "é": "es", "è": "ef", "ẻ": "er", "ẽ": "ex", "ẹ": "ej",
    "ê": "ee", "ế": "ees", "ề": "eef", "ể": "eer", "ễ": "eex", "ệ": "eej",
    "í": "is", "ì": "if", "ỉ": "ir", "ĩ": "ix", "ị": "ij",
    "ó": "os", "ò": "of", "ỏ": "or", "õ": "ox", "ọ": "oj",
    "ô": "oo", "ố": "oos", "ồ": "oof", "ổ": "oor", "ỗ": "oox", "ộ": "ooj",
    "ơ": "ow", "ớ": "ows", "ờ": "owf", "ở": "owr", "ỡ": "owx", "ợ": "owj",
    "ú": "us", "ù": "uf", "ủ": "ur", "ũ": "ux", "ụ": "uj",
    "ư": "uw", "ứ": "uws", "ừ": "uwf", "ử": "uwr", "ữ": "uwx", "ự": "uwj",
    "ý": "ys", "ỳ": "yf", "ỷ": "yr", "ỹ": "yx", "ỵ": "yj"
]

private func telexTypo(for word: String) -> String? {
    var result = ""
    var changed = false
    for character in word {
        let lower = Character(String(character).lowercased())
        guard let replacement = telexMisspellings[lower] else {
            result.append(character)
            continue
        }
        result += character.isUppercase ? replacement.uppercased() : replacement
        changed = true
    }
    return changed ? result : nil
}

private func randomWordTypo(for word: String, rng: inout RNG, telexProbability: Double) -> String? {
    let chars = Array(word)
    guard !chars.isEmpty else { return nil }
    if rng.unit() < telexProbability, let telex = telexTypo(for: word) { return telex }
    switch rng.int(0...3) {
    case 0: // Repeat a character: "text" -> "teext".
        let index = rng.int(0...(chars.count - 1))
        var changed = chars
        changed.insert(chars[index], at: index)
        return String(changed)
    case 1 where chars.count > 2: // Omit a character.
        var changed = chars
        changed.remove(at: rng.int(0...(chars.count - 1)))
        return String(changed)
    case 2 where chars.count > 2: // Swap adjacent characters.
        var changed = chars
        let index = rng.int(0...(chars.count - 2))
        changed.swapAt(index, index + 1)
        return String(changed)
    default: // Hit a neighbouring keyboard key.
        guard let index = chars.indices.randomElement(using: &rng), let replacement = typo(for: chars[index], rng: &rng) else { return nil }
        var changed = chars
        changed[index] = replacement
        return String(changed)
    }
}

private func naturalDelay(after character: Character, base: Double, burst: Double, rng: inout RNG) -> Double {
    var delay = base * burst * rng.between(0.58, 1.48)
    if character == " " { delay += rng.between(0.015, 0.09) }
    if ",;:".contains(character) { delay += rng.between(0.10, 0.34) }
    if ".!?".contains(character) { delay += rng.between(0.25, 0.80) }
    if character == "\n" { delay += rng.between(0.35, 1.10) }
    if rng.unit() < 0.012 { delay += rng.between(0.45, 1.8) }
    return max(0.012, delay)
}

enum DocumentPart {
    case text(String)
    case table(rows: Int, columns: Int, cells: [String])
    case manualCorrection(wrong: String, correct: String)
    case save
}

// The estimate uses the same configurable waits as the real run. It is
// intentionally approximate because typo locations and natural rhythm are
// random, but it includes their expected average cost.
private struct ProgressEstimatePlan {
    let totalCharacters: Int
    let typingSecondsPerCharacter: Double
    let saveSeconds: Double
    let expectedPeriodicSaves: Double
    let expectedAutomaticCorrections: Double
    let automaticCorrectionSeconds: Double
    let fixedOperationSeconds: [Double]
    let tableSeconds: [Double]

    func remainingSeconds(
        typed: Int,
        completedPeriodicSaves: Int,
        completedAutomaticCorrections: Int,
        completedFixedOperations: Int,
        completedTables: Int
    ) -> Double {
        let remaining = Double(max(0, totalCharacters - typed))
        let periodicSaves = max(0, expectedPeriodicSaves - Double(completedPeriodicSaves))
        let automaticCorrections = max(0, expectedAutomaticCorrections - Double(completedAutomaticCorrections))
        let pendingFixedOperations = fixedOperationSeconds
            .dropFirst(min(completedFixedOperations, fixedOperationSeconds.count))
            .reduce(0, +)
        let pendingTables = tableSeconds.dropFirst(min(completedTables, tableSeconds.count)).reduce(0, +)
        return remaining * typingSecondsPerCharacter
            + periodicSaves * saveSeconds
            + automaticCorrections * (saveSeconds + automaticCorrectionSeconds)
            + pendingFixedOperations
            + pendingTables
    }

    var initialSeconds: Double {
        remainingSeconds(
            typed: 0,
            completedPeriodicSaves: 0,
            completedAutomaticCorrections: 0,
            completedFixedOperations: 0,
            completedTables: 0
        )
    }
}

private func expandDirectives(_ parts: [DocumentPart]) -> [DocumentPart] {
    // Directives may be wrapped in Markdown backticks (or escaped backticks)
    // without those wrapper characters being typed into the document.
    let pattern = #"(?:\\?`)?\[([^,\]\n]+),\s*([^\]\n]+)\](?:\\?`)?|(?:\\?`)?\{save\}(?:\\?`)?"#
    let regex = try! NSRegularExpression(pattern: pattern)
    var output: [DocumentPart] = []
    for part in parts {
        guard case .text(let text) = part else { output.append(part); continue }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var cursor = text.startIndex
        for match in matches {
            guard let whole = Range(match.range, in: text) else { continue }
            if cursor < whole.lowerBound { output.append(.text(String(text[cursor..<whole.lowerBound]))) }
            if match.range(at: 1).location != NSNotFound,
               let wrongRange = Range(match.range(at: 1), in: text),
               let correctRange = Range(match.range(at: 2), in: text) {
                output.append(.manualCorrection(wrong: String(text[wrongRange]).trimmingCharacters(in: .whitespaces),
                                                correct: String(text[correctRange]).trimmingCharacters(in: .whitespaces)))
            } else {
                output.append(.save)
            }
            cursor = whole.upperBound
        }
        if cursor < text.endIndex { output.append(.text(String(text[cursor...]))) }
    }
    return output
}

private func convertMathBody(_ body: String) -> String {
    var result = body

    // Turn LaTeX fractions into a linear form that remains readable as plain
    // Unicode: \frac{A}{B} -> (A)/(B). The groups may contain nested braces.
    func bracedGroup(in value: String, from start: String.Index) -> (String, String.Index)? {
        guard start < value.endIndex, value[start] == "{" else { return nil }
        var depth = 0
        var index = start
        let contentStart = value.index(after: start)
        while index < value.endIndex {
            if value[index] == "{" { depth += 1 }
            if value[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return (String(value[contentStart..<index]), value.index(after: index))
                }
            }
            index = value.index(after: index)
        }
        return nil
    }

    while let fraction = result.range(of: #"\frac"#) {
        var numeratorStart = fraction.upperBound
        while numeratorStart < result.endIndex && result[numeratorStart].isWhitespace {
            numeratorStart = result.index(after: numeratorStart)
        }
        guard let numerator = bracedGroup(in: result, from: numeratorStart) else { break }
        var denominatorStart = numerator.1
        while denominatorStart < result.endIndex && result[denominatorStart].isWhitespace {
            denominatorStart = result.index(after: denominatorStart)
        }
        guard let denominator = bracedGroup(in: result, from: denominatorStart) else { break }
        result.replaceSubrange(fraction.lowerBound..<denominator.1, with: "(\(numerator.0))/(\(denominator.0))")
    }

    // Boxed math is a visual LaTex wrapper. Google Docs plain typing should
    // receive only its contents: \boxed{v(D)} -> v(D).
    while let boxed = result.range(of: #"\boxed"#) {
        var contentStart = boxed.upperBound
        while contentStart < result.endIndex && result[contentStart].isWhitespace {
            contentStart = result.index(after: contentStart)
        }
        guard let content = bracedGroup(in: result, from: contentStart) else { break }
        result.replaceSubrange(boxed.lowerBound..<content.1, with: content.0)
    }

    // Also accept TeX's compact single-token form: \frac14 -> 1/4.
    let compactFraction = try! NSRegularExpression(pattern: #"\\frac\s*([A-Za-z0-9])\s*([A-Za-z0-9])"#)
    result = compactFraction.stringByReplacingMatches(
        in: result,
        range: NSRange(result.startIndex..., in: result),
        withTemplate: "$1/$2"
    )

    // Commands whose argument should remain ordinary text.
    let textPattern = try! NSRegularExpression(pattern: #"\\text\{([^{}]*)\}"#)
    while let match = textPattern.firstMatch(
        in: result,
        range: NSRange(result.startIndex..., in: result)
    ), let wholeRange = Range(match.range(at: 0), in: result),
       let valueRange = Range(match.range(at: 1), in: result) {
        result.replaceSubrange(wholeRange, with: String(result[valueRange]))
    }

    let subscriptPattern = try! NSRegularExpression(pattern: #"_\{([^{}]+)\}"#)
    let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "i": "ᵢ", "j": "ⱼ", "n": "ₙ", "+": "₊", "-": "₋",
        "=": "₌", "(": "₍", ")": "₎"
    ]
    while let match = subscriptPattern.firstMatch(
        in: result,
        range: NSRange(result.startIndex..., in: result)
    ), let wholeRange = Range(match.range(at: 0), in: result),
       let valueRange = Range(match.range(at: 1), in: result) {
        let converted = result[valueRange].map { subscriptMap[$0] ?? $0 }
        result.replaceSubrange(wholeRange, with: String(converted))
    }

    let replacements: [(String, String)] = [
        (#"\leftrightarrow"#, "↔"), (#"\Rightarrow"#, "→"), (#"\Leftarrow"#, "←"),
        (#"\rightarrow"#, "→"), (#"\leftarrow"#, "←"),
        (#"\subseteq"#, "⊆"), (#"\supseteq"#, "⊇"), (#"\langle"#, "⟨"),
        (#"\rangle"#, "⟩"), (#"\notin"#, "∉"), (#"\infty"#, "∞"),
        (#"\forall"#, "∀"), (#"\exists"#, "∃"), (#"\times"#, "×"),
        (#"\approx"#, "≈"), (#"\cdot"#, "·"), (#"\neq"#, "≠"), (#"\leq"#, "≤"),
        (#"\geq"#, "≥"), (#"\le"#, "≤"), (#"\ge"#, "≥"),
        (#"\in"#, "∈"), (#"\cup"#, "∪"), (#"\cap"#, "∩"),
        (#"\to"#, "→"), (#"\mid"#, " | "), (#"\ln"#, "ln"),
        (#"\;"#, ""), (#"\,"#, ""), (#"\!"#, ""), (#"\ "#, ""),
        (#"\{"#, "{"), (#"\}"#, "}"), ("{,}", ","),
        ("_0", "₀"), ("_1", "₁"), ("_2", "₂"), ("_3", "₃"),
        ("_4", "₄"), ("_5", "₅"), ("_6", "₆"), ("_7", "₇"),
        ("_8", "₈"), ("_9", "₉"), ("_i", "ᵢ"), ("_j", "ⱼ"),
        ("_n", "ₙ")
    ]
    for (command, symbol) in replacements {
        result = result.replacingOccurrences(of: command, with: symbol)
    }
    return result
}

private func convertDelimitedMath(in text: String, opening: String, closing: String, collapseLines: Bool) -> String {
    var output = ""
    var remainder = text[...]

    while let start = remainder.range(of: opening) {
        output += remainder[..<start.lowerBound]
        let afterStart = remainder[start.upperBound...]
        guard let end = afterStart.range(of: closing) else {
            output += remainder[start.lowerBound...]
            return output
        }
        var body = String(afterStart[..<end.lowerBound])
        if collapseLines {
            body = body.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        output += convertMathBody(body)
        remainder = afterStart[end.upperBound...]
    }
    output += remainder
    return output
}

private func convertInlineMath(in text: String) -> String {
    let withDisplayMath = convertDelimitedMath(
        in: text, opening: #"\["#, closing: #"\]"#, collapseLines: true
    )
    return convertDelimitedMath(
        in: withDisplayMath, opening: #"\("#, closing: #"\)"#, collapseLines: false
    )
}

private func parseDocument(_ content: String) -> [DocumentPart] {
    let lines = convertInlineMath(in: content).components(separatedBy: "\n")
    var parts: [DocumentPart] = []
    var plain = ""
    var index = 0

    while index < lines.count {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[[TABLE "), trimmed.hasSuffix("]]"),
           let space = trimmed.firstIndex(of: " ") {
            let sizeText = String(trimmed[trimmed.index(after: space)..<trimmed.index(trimmed.endIndex, offsetBy: -2)])
            let dimensions = sizeText.lowercased().split(separator: "x")
            guard dimensions.count == 2,
                  let rows = Int(dimensions[0]), let columns = Int(dimensions[1]),
                  rows > 0, rows <= 20, columns > 0, columns <= 20 else {
                fail("khai báo bảng không hợp lệ ở dòng \(index + 1): \(trimmed)")
            }
            if !plain.isEmpty {
                parts.append(.text(plain))
                plain = ""
            }
            index += 1
            var tableRows: [[String]] = []
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces) != "[[ENDTABLE]]" {
                let cells = lines[index].split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard cells.count == columns else {
                    fail("dòng \(index + 1) của bảng cần đúng \(columns) ô, phân cách bằng dấu |")
                }
                tableRows.append(cells)
                index += 1
            }
            guard index < lines.count else { fail("bảng thiếu dòng [[ENDTABLE]]") }
            guard tableRows.count == rows else {
                fail("bảng \(rows)x\(columns) cần đúng \(rows) dòng dữ liệu, hiện có \(tableRows.count)")
            }
            parts.append(.table(rows: rows, columns: columns, cells: tableRows.flatMap { $0 }))
        } else {
            plain += lines[index]
            if index < lines.count - 1 { plain += "\n" }
        }
        index += 1
    }
    if !plain.isEmpty { parts.append(.text(plain)) }
    return expandDirectives(parts)
}

private func runGoogleDocsCommand(_ command: String, settleTime: Double = 0.35) {
    // Option + / opens Google Docs Tool Finder on macOS. Its first result is
    // highlighted automatically, so Enter runs it without an extra Down key.
    postShortcut(code: 44, flags: .maskAlternate)
    pumpEvents(for: 0.25)
    postText(command)
    pumpEvents(for: 0.35)
    postKey(code: 36)
    pumpEvents(for: settleTime)
}

private func visitGoogleDocsVersionHistory(viewTime: Double) {
    // Google Docs on macOS: Command + Option + Shift + H opens version history.
    let flags: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift]
    postShortcut(code: 4, flags: flags) // H
    pumpEvents(for: viewTime)
    if stopRequested { return }
    postKey(code: 53) // Plain Escape closes history; generated events never trigger emergency stop.
    pumpEvents(for: 0.8)
}

private func exitGoogleDocsTable() {
    // Official Google Docs shortcut on macOS: hold Control + Command + Shift,
    // then press T followed by E (Exit table).
    let flags: CGEventFlags = [.maskControl, .maskCommand, .maskShift]
    postShortcut(code: 17, flags: flags) // T
    pumpEvents(for: 0.12)
    postShortcut(code: 14, flags: flags) // E
    pumpEvents(for: 0.55)
}

private func createGoogleDocsTable(rows: Int, columns: Int, positionAtStart: Bool = true) {
    // In Google Docs, the Tool Finder command creates a 2x2 table immediately;
    // it does not open the table-size grid. The caret remains in the first cell,
    // so resize from there using table commands before typing cell contents.
    runGoogleDocsCommand("Chèn bảng", settleTime: 0.45)

    if columns > 2 {
        for _ in 2..<columns { runGoogleDocsCommand("Chèn cột bên phải") }
    } else if columns == 1 {
        runGoogleDocsCommand("Xóa cột")
    }

    if rows > 2 {
        for _ in 2..<rows { runGoogleDocsCommand("Chèn hàng bên dưới") }
    } else if rows == 1 {
        runGoogleDocsCommand("Xóa hàng")
    }

    // Keep this separate so --table-only can expose Docs' raw focus position.
    // After adding rows, Docs leaves the caret at row (rows - 1), column 1.
    // Therefore exactly (rows - 2) Up presses return it to row 1, column 1.
    if positionAtStart && rows > 2 {
        for _ in 0..<(rows - 2) {
            postKey(code: 126) // Up
            pumpEvents(for: 0.15)
        }
    }
    pumpEvents(for: 0.2)
}

let config = parseArguments()
let fileURL = findInputFile(named: config.fileName)
guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
    fail("không đọc được file UTF-8: \(fileURL.lastPathComponent)")
}

let documentParts = parseDocument(content)
let textCharacterCount = documentParts.reduce(0) { total, part in
    switch part {
    case .text(let text): return total + text.count
    case .table(_, _, let cells): return total + cells.reduce(0) { $0 + $1.count }
    case .manualCorrection(_, let correct): return total + correct.count
    case .save: return total
    }
}
let tableCount = documentParts.reduce(0) { total, part in
    if case .table = part { return total + 1 }
    return total
}

var finalText = ""
var tableDurations: [Double] = []
for part in documentParts {
    switch part {
    case .text(let text):
        finalText += text
    case .manualCorrection(_, let correct):
        finalText += correct
    case .save:
        break
    case .table(let rows, let columns, let cells):
        finalText += cells.joined()
        // Simple, predictable estimate requested for table creation:
        // every row costs 1 second and every column costs 1 second.
        tableDurations.append(Double(rows + columns))
    }
}
let baseTypingSeconds = 60.0 / (config.wpm * 5)
var rhythmExtraSeconds = 0.0
if config.naturalRhythm {
    for character in finalText {
        // Expected values of the random delays in naturalDelay().
        rhythmExtraSeconds += baseTypingSeconds * 0.03 + 0.0135
        if character == " " { rhythmExtraSeconds += 0.0525 }
        if ",;:".contains(character) { rhythmExtraSeconds += 0.22 }
        if ".!?".contains(character) { rhythmExtraSeconds += 0.525 }
        if character == "\n" { rhythmExtraSeconds += 0.725 }
    }
}
let averageRhythmExtra = finalText.isEmpty ? 0 : rhythmExtraSeconds / Double(finalText.count)
let saveSeconds = config.waitBeforeHistory + config.historyViewTime + config.waitAfterHistory + 0.8
let averageHistoryInterval = Double(config.historyMinCharacters + config.historyMaxCharacters) / 2
let expectedPeriodicSaves = config.longPauses && config.visitHistoryDuringPauses
    ? Double(textCharacterCount) / averageHistoryInterval
    : 0
let averageTyposPerCycle = Double(config.typosMinPerHistory + config.typosMaxPerHistory) / 2
let averageWords = max(1, finalText.split(whereSeparator: { $0.isWhitespace }).count)
let averageWordLength = Double(max(4, finalText.count / averageWords))
let averagePhraseWords = Double(config.typoPhraseMinWords + config.typoPhraseMaxWords) / 2
let averageTypoInterval = Double(config.typoMinCharacters + config.typoMaxCharacters) / 2
let intervalLimitedCorrections = Double(textCharacterCount) / averageTypoInterval
let correctionCycles = expectedPeriodicSaves > 0 ? expectedPeriodicSaves + 1 : 1
let expectedAutomaticCorrections = config.errorRate > 0
    ? min(intervalLimitedCorrections, correctionCycles * averageTyposPerCycle)
    : 0
let averagePhraseCharacters = averageWordLength * averagePhraseWords
let backspaceSecondsPerCharacter = baseTypingSeconds * 0.875
let automaticCorrectionSeconds = averagePhraseCharacters
    * (baseTypingSeconds + averageRhythmExtra + backspaceSecondsPerCharacter)
let fixedOperationDurations: [Double] = documentParts.compactMap { part in
    switch part {
    case .save:
        return saveSeconds
    case .manualCorrection(let wrong, _):
        let wrongTypingAndDeletion = Double(wrong.count)
            * (baseTypingSeconds + averageRhythmExtra + backspaceSecondsPerCharacter)
        return saveSeconds + wrongTypingAndDeletion
    default:
        return nil
    }
}
private let progressPlan = ProgressEstimatePlan(
    totalCharacters: textCharacterCount,
    typingSecondsPerCharacter: baseTypingSeconds + averageRhythmExtra,
    saveSeconds: saveSeconds,
    expectedPeriodicSaves: expectedPeriodicSaves,
    expectedAutomaticCorrections: expectedAutomaticCorrections,
    automaticCorrectionSeconds: automaticCorrectionSeconds,
    fixedOperationSeconds: fixedOperationDurations,
    tableSeconds: tableDurations
)
private var completedPeriodicSaveCount = 0
private var completedAutomaticCorrectionCount = 0
private var completedFixedOperationCount = 0
private var completedTableCount = 0
print("Đã đọc \(textCharacterCount) ký tự và \(tableCount) bảng từ \(fileURL.lastPathComponent).")
if config.dryRun {
    let estimate = progressPlan.initialSeconds
    print(String(
        format: "Ước tính đầy đủ %.1f giây (%.0f:%02.0f) ở %.0f WPM.",
        estimate, floor(estimate / 60), estimate.truncatingRemainder(dividingBy: 60), config.wpm
    ))
    print(String(
        format: "Dự kiến: %.1f lần lưu tự động, %.1f lỗi tự động, %d directive lưu/sửa và %d bảng.",
        expectedPeriodicSaves, expectedAutomaticCorrections, fixedOperationDurations.count, tableCount
    ))
    print(String(format: "Mỗi lần lưu/lỗi cộng trung bình %.1f giây theo settings.", saveSeconds))
    exit(0)
}

let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
let options = [promptKey: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(options) else {
    fail("hãy cấp quyền Accessibility cho Terminal, rồi chạy lại chương trình")
}

guard installSafetyMonitor() != nil else {
    fail("không tạo được bộ dừng an toàn; kiểm tra quyền Accessibility")
}

NSApplication.shared.setActivationPolicy(.accessory)
progressOverlay = ProgressOverlay(total: textCharacterCount, estimateRemaining: { typed in
    progressPlan.remainingSeconds(
        typed: typed,
        completedPeriodicSaves: completedPeriodicSaveCount,
        completedAutomaticCorrections: completedAutomaticCorrectionCount,
        completedFixedOperations: completedFixedOperationCount,
        completedTables: completedTableCount
    )
})
progressOverlay?.show(status: config.countdown > 0 ? "Chuẩn bị bắt đầu" : "Đang gõ")

if config.countdown > 0 {
    for second in stride(from: config.countdown, through: 1, by: -1) {
        print("Bắt đầu sau \(second)…", terminator: "\r")
        fflush(stdout)
        progressOverlay?.showCountdown(second)
        pumpEvents(for: 1)
        if stopRequested { break }
    }
    print(String(repeating: " ", count: 32), terminator: "\r")
}
progressOverlay?.startElapsed()

var rng = RNG(seed: config.seed ?? UInt64(Date().timeIntervalSince1970 * 1_000_000))
let baseDelay = 60.0 / (config.wpm * 5.0)
var burstFactor = 1.0
var untilBurstChange = rng.int(3...12)
var typed = 0
var typedSinceLongPause = 0
var nextLongPauseAt = rng.int(config.historyMinCharacters...config.historyMaxCharacters)
var longPauseCount = 0
var charactersSinceTypo = 0
var typosThisHistoryCycle = 0
var targetTyposThisHistoryCycle = rng.int(config.typosMinPerHistory...config.typosMaxPerHistory)

func typeCharacter(_ character: Character) {
    if stopRequested { return }

    if config.naturalRhythm && untilBurstChange == 0 {
        burstFactor = rng.between(0.72, 1.32)
        untilBurstChange = rng.int(3...12)
    }
    if config.naturalRhythm { untilBurstChange -= 1 }

    postText(String(character))
    typed += 1
    typedSinceLongPause += 1
    progressOverlay?.update(status: "Đang gõ", typed: typed)
    // Plain mode is deliberately constant: no punctuation pauses, bursts, or
    // random breaks—only the delay required by the selected WPM.
    let delay = !config.naturalRhythm
        ? baseDelay
        : naturalDelay(after: character, base: baseDelay, burst: burstFactor, rng: &rng)
    pumpEvents(for: delay)

    if config.longPauses && config.visitHistoryDuringPauses && typedSinceLongPause >= nextLongPauseAt && !stopRequested {
        longPauseCount += 1
        print("\nLần nghỉ \(longPauseCount) tại ký tự \(typed): đang chờ \(config.waitBeforeHistory) giây trước khi mở lịch sử…")
        progressOverlay?.update(status: "Đang chờ trước khi lưu", typed: typed, force: true)
        pumpEvents(for: config.waitBeforeHistory)
        if !stopRequested {
            print("Đang mở lịch sử phiên bản rồi quay lại…")
            progressOverlay?.update(status: "Đang xem lịch sử phiên bản", typed: typed, force: true)
            visitGoogleDocsVersionHistory(viewTime: config.historyViewTime)
        }
        if !stopRequested {
            print("Đang nghỉ thêm \(config.waitAfterHistory) giây trước khi tiếp tục gõ…")
            progressOverlay?.update(status: "Đang chờ để tiếp tục gõ", typed: typed, force: true)
            pumpEvents(for: config.waitAfterHistory)
        }
        if !stopRequested { completedPeriodicSaveCount += 1 }
        typedSinceLongPause = 0
        nextLongPauseAt = rng.int(config.historyMinCharacters...config.historyMaxCharacters)
        typosThisHistoryCycle = 0
        targetTyposThisHistoryCycle = rng.int(config.typosMinPerHistory...config.typosMaxPerHistory)
        charactersSinceTypo = 0
    }
}

func correctPhrase(wrong: String, correct: String, automatic: Bool) {
    guard !stopRequested else { return }

    // Randomize whether the history pause happens before or after correction.
    let saveBeforeCorrection = rng.unit() < config.historyBeforeCorrectionProbability
    if saveBeforeCorrection {
        print("\nĐang lưu phiên bản trước khi sửa ‘\(wrong)’…")
        progressOverlay?.update(status: "Đang lưu trước khi sửa lỗi", typed: typed, force: true)
        pumpEvents(for: config.waitBeforeHistory)
        if !stopRequested { visitGoogleDocsVersionHistory(viewTime: config.historyViewTime) }
        if !stopRequested { pumpEvents(for: config.waitAfterHistory) }
    }
    guard !stopRequested else { return }

    for _ in wrong {
        postKey(code: 51) // Backspace
        pumpEvents(for: rng.between(baseDelay * 0.55, baseDelay * 1.2))
    }
    // The panel reports final document characters, not transient typo text.
    typed = max(0, typed - wrong.count)
    progressOverlay?.update(status: "Đang sửa lỗi gõ", typed: typed, force: true)
    for character in correct {
        postText(String(character))
        typed += 1
        progressOverlay?.update(status: "Đang sửa lỗi gõ", typed: typed)
        pumpEvents(for: naturalDelay(after: character, base: baseDelay, burst: burstFactor, rng: &rng))
    }
    if !stopRequested && !saveBeforeCorrection {
        print("\nĐang lưu phiên bản sau khi sửa ‘\(correct)’…")
        progressOverlay?.update(status: "Đang lưu sau khi sửa lỗi", typed: typed, force: true)
        pumpEvents(for: config.waitBeforeHistory)
        if !stopRequested { visitGoogleDocsVersionHistory(viewTime: config.historyViewTime) }
        if !stopRequested { pumpEvents(for: config.waitAfterHistory) }
    }
    if !stopRequested {
        if automatic {
            completedAutomaticCorrectionCount += 1
        } else {
            completedFixedOperationCount += 1
        }
    }
}

func typeString(_ text: String) {
    var tokens: [(value: String, isWord: Bool)] = []
    var buffer = ""
    var bufferIsWord: Bool?
    for character in text {
        let isWord = !character.isWhitespace
        if let current = bufferIsWord, current != isWord {
            tokens.append((buffer, current))
            buffer = ""
        }
        bufferIsWord = isWord
        buffer.append(character)
    }
    if let current = bufferIsWord { tokens.append((buffer, current)) }

    var index = 0
    while index < tokens.count && !stopRequested {
        guard tokens[index].isWord else {
            for character in tokens[index].value { typeCharacter(character) }
            index += 1
            continue
        }
        let shouldMistype = config.errorRate > 0 && typosThisHistoryCycle < targetTyposThisHistoryCycle &&
            charactersSinceTypo >= rng.int(config.typoMinCharacters...config.typoMaxCharacters)
        guard shouldMistype else {
            for character in tokens[index].value { typeCharacter(character) }
            charactersSinceTypo += tokens[index].value.count
            index += 1
            continue
        }
        let targetWords = rng.int(config.typoPhraseMinWords...config.typoPhraseMaxWords)
        var end = index
        var wordCount = 0
        var correct = ""
        var wrong = ""
        while end < tokens.count && wordCount < targetWords {
            let token = tokens[end]
            correct += token.value
            if token.isWord {
                wrong += randomWordTypo(for: token.value, rng: &rng, telexProbability: config.telexTypoProbability) ?? token.value
                wordCount += 1
            } else {
                wrong += token.value
            }
            end += 1
        }
        if wrong != correct {
            for character in wrong { typeCharacter(character) }
            typosThisHistoryCycle += 1
            charactersSinceTypo = 0
            correctPhrase(wrong: wrong, correct: correct, automatic: true)
        } else {
            for character in correct { typeCharacter(character) }
        }
        charactersSinceTypo += correct.count
        index = end
    }
}

func typeLiteral(_ text: String) {
    for character in text where !stopRequested { typeCharacter(character) }
}

documentLoop: for part in documentParts {
    if stopRequested { break }
    switch part {
    case .text(let text):
        typeString(text)
    case .manualCorrection(let wrong, let correct):
        print("\nĐang xử lý lỗi thủ công ‘\(wrong)’ → ‘\(correct)’…")
        progressOverlay?.update(status: "Đang xử lý lỗi thủ công", typed: typed, force: true)
        typeLiteral(wrong)
        correctPhrase(wrong: wrong, correct: correct, automatic: false)
    case .save:
        print("\nĐang lưu lịch sử theo directive {save}…")
        progressOverlay?.update(status: "Đang lưu lịch sử", typed: typed, force: true)
        pumpEvents(for: config.waitBeforeHistory)
        if !stopRequested { visitGoogleDocsVersionHistory(viewTime: config.historyViewTime) }
        if !stopRequested { pumpEvents(for: config.waitAfterHistory) }
        if !stopRequested { completedFixedOperationCount += 1 }
    case .table(let rows, let columns, let cells):
        print("\nĐang tạo bảng \(rows)x\(columns)…")
        progressOverlay?.update(status: "Đang tạo bảng \(rows)x\(columns)", typed: typed, force: true)
        createGoogleDocsTable(rows: rows, columns: columns, positionAtStart: !config.tableOnly)
        if config.tableOnly {
            print("Đã tạo bảng; không điều hướng hoặc nhập nội dung để kiểm tra focus.")
            break documentLoop
        }
        if config.positionOnly {
            print("Đã nhấn phím Lên \(max(0, rows - 2)) lần; không nhập nội dung.")
            break documentLoop
        }
        for (index, cell) in cells.enumerated() {
            if stopRequested { break }
            typeString(cell)
            if index < cells.count - 1 {
                postKey(code: 48) // Tab: next table cell.
                pumpEvents(for: rng.between(0.18, 0.42))
            }
        }
        if !stopRequested {
            exitGoogleDocsTable()
            completedTableCount += 1
        }
    }
}

if stopRequested {
    progressOverlay?.close()
    print("\nĐã dừng an toàn sau \(typed)/\(textCharacterCount) ký tự.")
    exit(130)
}
let elapsed = progressOverlay?.finish(typed: typed) ?? 0
print("\nHoàn tất: đã gõ \(typed) ký tự trong \(String(format: "%.1f", elapsed)) giây.")
pumpEvents(for: 4)
progressOverlay?.close()
