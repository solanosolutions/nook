import AppKit
import CoreAudio

/// Capta só o áudio do Spotify (Core Audio process tap, macOS 14.2+) e calcula 5 faixas de frequência
/// para as barras e ondas, com a mesma análise da versão Windows (FFT de 1024 pontos, ganho automático por faixa).
///
/// Na primeira vez o macOS pede a permissão "Gravação de Áudio do Sistema" (Ajustes › Privacidade e Segurança ›
/// Gravação de Tela e Áudio do Sistema). Sem a permissão, ou no macOS 13–14.1, o tap não entrega som:
/// o visualizador percebe (`live` falso) e volta para a animação própria.
final class AudioTap {
    static let bandCount = 5
    private static let n = 1024 // janela da FFT (~23 ms a 44.1 kHz)
    private static let edges: [Double] = [40, 150, 400, 1000, 2500, 8000]
    private static let hann: [Float] = (0..<n).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n - 1))) }

    private var users = 0
    private var suspended = false
    private var retry: Timer?

    private static let unknown = AudioObjectID(kAudioObjectUnknown)
    private var tapID = unknown
    private var aggregateID = unknown
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "nook.audio", qos: .userInteractive)

    // Estado da thread de áudio.
    private var ring = [Float](repeating: 0, count: n)
    private var write = 0, fresh = 0
    private var sampleRate = 48000.0
    private var re = [Float](repeating: 0, count: n), im = [Float](repeating: 0, count: n)
    private var peakDb = [Double](repeating: -30, count: bandCount)

    // Resultado, lido pela interface.
    private let lock = NSLock()
    private var _bands = [Float](repeating: 0, count: bandCount)
    private var lastSignal = Date.distantPast

    /// Níveis de 0 a 1 por faixa (graves → agudos).
    var bands: [Float] { lock.lock(); defer { lock.unlock() }; return _bands }

    /// Está chegando som de verdade (permissão dada e Spotify tocando).
    var live: Bool {
        lock.lock(); defer { lock.unlock() }
        return Date().timeIntervalSince(lastSignal) < 1.5
    }

    // ---------- Quem usa: o visualizador liga e desliga; o player escondido suspende ----------

    func retain() { users += 1; update() }
    func release() { users = max(0, users - 1); update() }
    func setSuspended(_ s: Bool) { suspended = s; update() }
    /// O Spotify abriu ou fechou: refaz o tap para pegar os processos novos.
    func restart() { stop(); update() }

    private var wanted: Bool { users > 0 && !suspended }

    private func update() {
        if wanted {
            if procID == nil && !start() { scheduleRetry() }
        } else {
            retry?.invalidate(); retry = nil
            stop()
        }
    }

    /// O Spotify só vira "processo de áudio" depois de tocar algo; tenta de novo em alguns segundos.
    private func scheduleRetry() {
        guard retry == nil else { return }
        let t = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.wanted || self.procID != nil || self.start() { self.retry?.invalidate(); self.retry = nil }
        }
        RunLoop.main.add(t, forMode: .common)
        retry = t
    }

    // ---------- Core Audio ----------

    private func start() -> Bool {
        guard #available(macOS 14.2, *) else { return false }
        let processes = Self.spotifyProcesses()
        guard !processes.isEmpty else { return false }

        let desc = CATapDescription(stereoMixdownOfProcesses: processes)
        desc.name = "Nook"
        desc.isPrivate = true
        // muteBehavior fica no padrão (não muta): o som continua saindo normal.
        var tap = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(desc, &tap) == noErr else { return false }
        tapID = tap

        var dict: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Nook Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        if let out = Self.defaultOutputUID() {
            dict[kAudioAggregateDeviceMainSubDeviceKey] = out
            dict[kAudioAggregateDeviceSubDeviceListKey] = [[kAudioSubDeviceUIDKey: out]]
        }
        var agg = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(dict as CFDictionary, &agg) == noErr else { stop(); return false }
        aggregateID = agg

        if let fmt = Self.tapFormat(tap), fmt.mSampleRate > 0 { sampleRate = fmt.mSampleRate }

        var proc: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&proc, agg, queue) { [weak self] _, input, _, _, _ in
            self?.consume(input)
        }
        guard status == noErr, let proc else { stop(); return false }
        procID = proc
        guard AudioDeviceStart(agg, proc) == noErr else { stop(); return false }
        return true
    }

    private func stop() {
        if let proc = procID {
            AudioDeviceStop(aggregateID, proc)
            AudioDeviceDestroyIOProcID(aggregateID, proc)
        }
        procID = nil
        if aggregateID != Self.unknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = Self.unknown
        if tapID != Self.unknown {
            if #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tapID) }
        }
        tapID = Self.unknown
        lock.lock(); _bands = [Float](repeating: 0, count: Self.bandCount); lastSignal = .distantPast; lock.unlock()
    }

    // ---------- Thread de áudio ----------

    private func consume(_ input: UnsafePointer<AudioBufferList>) {
        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        var heard = false
        for buf in list {
            guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let ch = max(1, Int(buf.mNumberChannels))
            let frames = Int(buf.mDataByteSize) / (MemoryLayout<Float>.size * ch)
            for f in 0..<frames {
                var s: Float = 0
                for c in 0..<ch { s += data[f * ch + c] }
                s /= Float(ch)
                if s != 0 { heard = true }
                ring[write] = s
                write = (write + 1) & (Self.n - 1)
            }
            fresh += frames
        }
        if heard { lock.lock(); lastSignal = Date(); lock.unlock() }
        if fresh >= Self.n / 2 {
            fresh = 0
            let b = analyze()
            lock.lock(); _bands = b; lock.unlock()
        }
    }

    // Ganho automático por faixa: o topo acompanha o pico recente e desce devagar,
    // então as barras mostram a variação (a batida), não o volume absoluto.
    private static let range = 18.0     // dB visíveis abaixo do pico recente
    private static let peakFall = 0.06  // dB por análise

    private func analyze() -> [Float] {
        let n = Self.n
        for i in 0..<n {
            re[i] = ring[(write + i) & (n - 1)] * Self.hann[i]
            im[i] = 0
        }
        Self.fft(&re, &im)
        var out = [Float](repeating: 0, count: Self.bandCount)
        let binHz = sampleRate / Double(n)
        for b in 0..<Self.bandCount {
            let lo = max(1, Int(Self.edges[b] / binHz))
            let hi = min(n / 2 - 1, max(lo, Int(Self.edges[b + 1] / binHz)))
            var peak: Float = 0
            if lo <= hi {
                for k in lo...hi { peak = max(peak, (re[k] * re[k] + im[k] * im[k]).squareRoot()) }
            }
            let db = 20 * log10(Double(peak) / (Double(n) / 4) + 1e-9)
            peakDb[b] = max(db, max(peakDb[b] - Self.peakFall, -45)) // piso: silêncio não vira ruído
            let x = min(max((db - (peakDb[b] - Self.range)) / Self.range, 0), 1)
            out[b] = Float(x * x) // realça o contraste entre batida e vale
        }
        return out
    }

    private static func fft(_ re: inout [Float], _ im: inout [Float]) {
        let n = re.count
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 { j ^= bit; bit >>= 1 }
            j ^= bit
            if i < j { re.swapAt(i, j); im.swapAt(i, j) }
        }
        var len = 2
        while len <= n {
            let ang = -2 * Double.pi / Double(len)
            let wr = Float(cos(ang)), wi = Float(sin(ang))
            var i = 0
            while i < n {
                var cr: Float = 1, ci: Float = 0
                for k in 0..<(len / 2) {
                    let a = i + k, b = a + len / 2
                    let xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr
                    re[b] = re[a] - xr; im[b] = im[a] - xi
                    re[a] += xr; im[a] += xi
                    let t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t
                }
                i += len
            }
            len <<= 1
        }
    }

    // ---------- Consultas ----------

    /// Processos de áudio do Spotify (o app e os helpers dele).
    @available(macOS 14.2, *)
    private static func spotifyProcesses() -> [AudioObjectID] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { (stringProperty($0, kAudioProcessPropertyBundleID) ?? "").hasPrefix(SpotifyService.bundleID) }
    }

    private static func defaultOutputUID() -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var dev = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
              dev != unknown else { return nil }
        return stringProperty(dev, kAudioDevicePropertyDeviceUID)
    }

    @available(macOS 14.2, *)
    private static func tapFormat(_ tap: AudioObjectID) -> AudioStreamBasicDescription? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var fmt = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        return AudioObjectGetPropertyData(tap, &addr, 0, nil, &size, &fmt) == noErr ? fmt : nil
    }

    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: selector,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
