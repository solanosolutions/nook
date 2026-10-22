using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace Nook;

/// <summary>
/// Captura o áudio de um único processo (e filhos) via "process loopback" do Windows
/// e reduz para alguns níveis de frequência (0..1) para o visualizador.
/// pid = 0 captura tudo, exceto o próprio Nook.
/// </summary>
public sealed class AudioCapture
{
    public const int BandCount = 5;
    const int N = 1024; // janela da FFT (~23 ms a 44.1 kHz)
    const int SampleRate = 44100;
    static readonly double[] Edges = { 40, 150, 400, 1000, 2500, 8000 };
    static readonly float[] Hann = BuildHann();

    Thread? _thread;
    volatile bool _run;
    int _pid = -1;

    /// <summary>Último resultado da análise; trocado inteiro (sem lock) pela thread de áudio.</summary>
    public volatile float[] Bands = new float[BandCount];
    public volatile bool Failed;
    public event Action? FailedChanged;
    public bool Running => _thread != null;

    public void Start(int pid)
    {
        if (Running && pid == _pid) return;
        Stop();
        _pid = pid;
        _run = true;
        _thread = new Thread(() => Loop(pid)) { IsBackground = true, Name = "NookAudio" };
        _thread.SetApartmentState(ApartmentState.MTA);
        _thread.Start();
    }

    public void Stop()
    {
        _run = false;
        _thread?.Join(500);
        _thread = null;
        Bands = new float[BandCount];
    }

    void Loop(int pid)
    {
        IAudioClient? client = null;
        IAudioCaptureClient? capture = null;
        IntPtr format = IntPtr.Zero;
        try
        {
            client = Activate(pid);

            // 16-bit PCM estéreo 44.1 kHz; o Windows converte o que vier (AUTOCONVERTPCM).
            format = Marshal.AllocHGlobal(18);
            Marshal.WriteInt16(format, 0, 1);                 // WAVE_FORMAT_PCM
            Marshal.WriteInt16(format, 2, 2);                 // canais
            Marshal.WriteInt32(format, 4, SampleRate);
            Marshal.WriteInt32(format, 8, SampleRate * 4);    // bytes/s
            Marshal.WriteInt16(format, 12, 4);                // block align
            Marshal.WriteInt16(format, 14, 16);               // bits
            Marshal.WriteInt16(format, 16, 0);

            const uint flags = 0x00020000 | 0x00040000 | 0x80000000; // LOOPBACK | EVENTCALLBACK | AUTOCONVERTPCM
            Check(client.Initialize(0, flags, 200_000, 0, format, IntPtr.Zero));

            using var ready = new AutoResetEvent(false);
            Check(client.SetEventHandle(ready.SafeWaitHandle.DangerousGetHandle()));
            Check(client.GetService(typeof(IAudioCaptureClient).GUID, out object svc));
            capture = (IAudioCaptureClient)svc;
            Check(client.Start());

            var ring = new float[N];
            var re = new float[N];
            var im = new float[N];
            int write = 0, fresh = 0;

            while (_run)
            {
                ready.WaitOne(100);
                while (_run && capture.GetNextPacketSize(out uint packet) == 0 && packet > 0)
                {
                    if (capture.GetBuffer(out IntPtr data, out uint frames, out uint bufFlags, out _, out _) != 0) break;
                    bool silent = (bufFlags & 0x2) != 0;
                    for (int f = 0; f < frames; f++)
                    {
                        float s = silent ? 0f
                            : (Marshal.ReadInt16(data, f * 4) + Marshal.ReadInt16(data, f * 4 + 2)) / 65536f;
                        ring[write] = s;
                        write = (write + 1) & (N - 1);
                    }
                    fresh += (int)frames;
                    capture.ReleaseBuffer(frames);
                }
                if (fresh >= N / 2)
                {
                    fresh = 0;
                    Bands = Analyze(ring, write, re, im);
                }
            }
            client.Stop();
        }
        catch
        {
            Failed = true;
            FailedChanged?.Invoke();
        }
        finally
        {
            if (format != IntPtr.Zero) Marshal.FreeHGlobal(format);
            if (capture != null) Marshal.ReleaseComObject(capture);
            if (client != null) Marshal.ReleaseComObject(client);
        }
    }

    static void Check(int hr) { if (hr < 0) Marshal.ThrowExceptionForHR(hr); }

    // ---------- Análise ----------

    // Ganho automático por banda: o topo acompanha o pico recente e desce devagar,
    // então as barras mostram a variação (a batida), não o volume absoluto.
    readonly double[] _peakDb = { -30, -30, -30, -30, -30 };
    const double Range = 18;        // dB visíveis abaixo do pico recente
    const double PeakFall = 0.06;   // dB por análise (~5 dB/s)

    float[] Analyze(float[] ring, int write, float[] re, float[] im)
    {
        for (int i = 0; i < N; i++)
        {
            re[i] = ring[(write + i) & (N - 1)] * Hann[i];
            im[i] = 0;
        }
        Fft(re, im);

        var bands = new float[BandCount];
        double binHz = (double)SampleRate / N;
        for (int b = 0; b < BandCount; b++)
        {
            int lo = Math.Max(1, (int)(Edges[b] / binHz));
            int hi = Math.Max(lo, (int)(Edges[b + 1] / binHz));
            float peak = 0;
            for (int k = lo; k <= hi; k++)
            {
                float m = MathF.Sqrt(re[k] * re[k] + im[k] * im[k]);
                if (m > peak) peak = m;
            }
            double db = 20 * Math.Log10(peak / (N / 4.0) + 1e-9);
            _peakDb[b] = Math.Max(db, Math.Max(_peakDb[b] - PeakFall, -45)); // piso: silêncio não vira ruído
            double x = Math.Clamp((db - (_peakDb[b] - Range)) / Range, 0, 1);
            bands[b] = (float)Math.Pow(x, 2.0); // realça o contraste entre batida e vale
        }
        return bands;
    }

    static void Fft(float[] re, float[] im)
    {
        int n = re.Length;
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) { (re[i], re[j]) = (re[j], re[i]); (im[i], im[j]) = (im[j], im[i]); }
        }
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = -2 * Math.PI / len;
            float wr = (float)Math.Cos(ang), wi = (float)Math.Sin(ang);
            for (int i = 0; i < n; i += len)
            {
                float cr = 1, ci = 0;
                for (int k = 0; k < len / 2; k++)
                {
                    int a = i + k, b = a + len / 2;
                    float xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
                    re[b] = re[a] - xr; im[b] = im[a] - xi;
                    re[a] += xr; im[a] += xi;
                    float t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
                }
            }
        }
    }

    static float[] BuildHann()
    {
        var w = new float[N];
        for (int i = 0; i < N; i++) w[i] = (float)(0.5 - 0.5 * Math.Cos(2 * Math.PI * i / (N - 1)));
        return w;
    }

    // ---------- Ativação do process loopback ----------

    static IAudioClient Activate(int pid)
    {
        // AUDIOCLIENT_ACTIVATION_PARAMS { type = PROCESS_LOOPBACK, { pid, mode } }
        IntPtr prms = Marshal.AllocHGlobal(12);
        IntPtr prop = Marshal.AllocHGlobal(24);
        try
        {
            Marshal.WriteInt32(prms, 0, 1);
            Marshal.WriteInt32(prms, 4, pid == 0 ? Environment.ProcessId : pid);
            Marshal.WriteInt32(prms, 8, pid == 0 ? 1 : 0); // 1 = excluir árvore (o Nook), 0 = incluir árvore (Spotify)

            for (int i = 0; i < 24; i += 8) Marshal.WriteInt64(prop, i, 0);
            Marshal.WriteInt16(prop, 0, 65);       // VT_BLOB
            Marshal.WriteInt32(prop, 8, 12);       // blob.cbSize
            Marshal.WriteIntPtr(prop, 16, prms);   // blob.pBlobData

            var handler = new ActivationHandler();
            ActivateAudioInterfaceAsync("VAD\\Process_Loopback", typeof(IAudioClient).GUID, prop, handler, out _);
            if (!handler.Done.Wait(3000)) throw new TimeoutException();
            Check(handler.Hr);
            return handler.Client ?? throw new InvalidOperationException();
        }
        finally
        {
            Marshal.FreeHGlobal(prop);
            Marshal.FreeHGlobal(prms);
        }
    }

    [DllImport("Mmdevapi.dll", ExactSpelling = true, PreserveSig = false)]
    static extern void ActivateAudioInterfaceAsync(
        [MarshalAs(UnmanagedType.LPWStr)] string deviceInterfacePath,
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        IntPtr activationParams,
        IActivateAudioInterfaceCompletionHandler completionHandler,
        out IActivateAudioInterfaceAsyncOperation operation);

    sealed class ActivationHandler : IActivateAudioInterfaceCompletionHandler, IAgileObject
    {
        public readonly ManualResetEventSlim Done = new();
        public IAudioClient? Client;
        public int Hr;

        public void ActivateCompleted(IActivateAudioInterfaceAsyncOperation op)
        {
            try
            {
                op.GetActivateResult(out Hr, out object iface);
                if (Hr >= 0) Client = (IAudioClient)iface;
            }
            catch (Exception ex) { Hr = ex.HResult; }
            finally { Done.Set(); }
        }
    }

    [ComImport, Guid("72A22D78-CDE4-431D-B8CC-843A71199B6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IActivateAudioInterfaceAsyncOperation
    {
        void GetActivateResult(out int activateResult, [MarshalAs(UnmanagedType.IUnknown)] out object activatedInterface);
    }

    [ComImport, Guid("41D949AB-9862-444A-80F6-C261334DA5EB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IActivateAudioInterfaceCompletionHandler
    {
        void ActivateCompleted(IActivateAudioInterfaceAsyncOperation operation);
    }

    [ComImport, Guid("94EA2B94-E9CC-49E0-C0FF-EE64CA8F5B90"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAgileObject { }

    [ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioClient
    {
        [PreserveSig] int Initialize(int shareMode, uint streamFlags, long bufferDuration, long periodicity, IntPtr format, IntPtr sessionGuid);
        [PreserveSig] int GetBufferSize(out uint frames);
        [PreserveSig] int GetStreamLatency(out long latency);
        [PreserveSig] int GetCurrentPadding(out uint padding);
        [PreserveSig] int IsFormatSupported(int shareMode, IntPtr format, out IntPtr closest);
        [PreserveSig] int GetMixFormat(out IntPtr format);
        [PreserveSig] int GetDevicePeriod(out long defaultPeriod, out long minimumPeriod);
        [PreserveSig] int Start();
        [PreserveSig] int Stop();
        [PreserveSig] int Reset();
        [PreserveSig] int SetEventHandle(IntPtr handle);
        [PreserveSig] int GetService([MarshalAs(UnmanagedType.LPStruct)] Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object service);
    }

    [ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioCaptureClient
    {
        [PreserveSig] int GetBuffer(out IntPtr data, out uint frames, out uint flags, out ulong devicePosition, out ulong qpcPosition);
        [PreserveSig] int ReleaseBuffer(uint frames);
        [PreserveSig] int GetNextPacketSize(out uint frames);
    }
}
