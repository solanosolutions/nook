using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace Nook;

static class Native
{
    [StructLayout(LayoutKind.Sequential)]
    struct AccentPolicy { public int AccentState; public int AccentFlags; public uint GradientColor; public int AnimationId; }

    [StructLayout(LayoutKind.Sequential)]
    struct WindowCompositionAttributeData { public int Attribute; public IntPtr Data; public int SizeOfData; }

    [DllImport("user32.dll")] static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr hwnd, IntPtr hRgn, bool redraw);
    [DllImport("gdi32.dll")] static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int w, int h);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    const int GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80, WS_EX_APPWINDOW = 0x40000;

    /// <summary>Blur do Windows atrás da janela (vidro). Desliga com enabled=false.</summary>
    public static void SetBlur(Window w, bool enabled)
    {
        var hwnd = new WindowInteropHelper(w).Handle;
        if (hwnd == IntPtr.Zero) return;
        var accent = new AccentPolicy { AccentState = enabled ? 3 : 0 }; // 3 = ACCENT_ENABLE_BLURBEHIND
        int size = Marshal.SizeOf(accent);
        IntPtr ptr = Marshal.AllocHGlobal(size);
        try
        {
            Marshal.StructureToPtr(accent, ptr, false);
            var data = new WindowCompositionAttributeData { Attribute = 19, Data = ptr, SizeOfData = size };
            SetWindowCompositionAttribute(hwnd, ref data);
        }
        finally { Marshal.FreeHGlobal(ptr); }
    }

    /// <summary>Recorta a janela com cantos arredondados, para o blur não vazar nas quinas.</summary>
    public static void RoundCorners(Window w, double radius)
    {
        var hwnd = new WindowInteropHelper(w).Handle;
        var src = PresentationSource.FromVisual(w);
        if (hwnd == IntPtr.Zero || src?.CompositionTarget == null) return;
        double dpi = src.CompositionTarget.TransformToDevice.M11;
        int width = (int)Math.Ceiling(w.ActualWidth * dpi), height = (int)Math.Ceiling(w.ActualHeight * dpi);
        int r = (int)(radius * 2 * dpi);
        SetWindowRgn(hwnd, CreateRoundRectRgn(0, 0, width + 1, height + 1, r, r), true);
    }

    /// <summary>Some do Alt+Tab e da barra de tarefas.</summary>
    public static void MakeToolWindow(Window w)
    {
        var hwnd = new WindowInteropHelper(w).Handle;
        int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, (ex | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW);
    }

    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")] static extern bool SetProcessWorkingSetSize(IntPtr proc, IntPtr min, IntPtr max);

    /// <summary>Libera a memória usada só na inicialização e devolve as páginas ociosas ao Windows.</summary>
    public static void TrimMemory()
    {
        GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced, blocking: true, compacting: true);
        GC.WaitForPendingFinalizers();
        SetProcessWorkingSetSize(GetCurrentProcess(), (IntPtr)(-1), (IntPtr)(-1));
    }

    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder name, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("shell32.dll")] static extern int SHQueryUserNotificationState(out int state);

    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct MONITORINFO { public int Size; public RECT Monitor, Work; public uint Flags; }

    const int WS_CAPTION = 0x00C00000, GWL_STYLE = -16;

    /// <summary>
    /// True se a janela em primeiro plano está em tela cheia no MESMO monitor do Nook.
    /// Janela maximizada comum não conta: exige cobrir o monitor inteiro e estar sem barra de título
    /// (ou o Windows reportar modo tela cheia / jogo / apresentação).
    /// </summary>
    public static bool IsFullscreenOnMyMonitor(Window self)
    {
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero) return false;

        GetWindowThreadProcessId(fg, out uint pid);
        if (pid == (uint)Environment.ProcessId) return false;

        var cls = new System.Text.StringBuilder(64);
        GetClassName(fg, cls, cls.Capacity);
        string c = cls.ToString();
        if (c is "Progman" or "WorkerW" or "Shell_TrayWnd" or "Shell_SecondaryTrayWnd") return false; // área de trabalho/barra

        IntPtr mine = new WindowInteropHelper(self).Handle;
        IntPtr mon = MonitorFromWindow(fg, 2);
        if (mon != MonitorFromWindow(mine, 2)) return false;

        var mi = new MONITORINFO { Size = Marshal.SizeOf<MONITORINFO>() };
        if (!GetMonitorInfo(mon, ref mi) || !GetWindowRect(fg, out RECT r)) return false;
        bool coversMonitor = r.Left <= mi.Monitor.Left && r.Top <= mi.Monitor.Top
                             && r.Right >= mi.Monitor.Right && r.Bottom >= mi.Monitor.Bottom;
        if (!coversMonitor) return false;

        bool noCaption = (GetWindowLong(fg, GWL_STYLE) & WS_CAPTION) != WS_CAPTION;
        bool osSaysFullscreen = SHQueryUserNotificationState(out int s) == 0 && s is 2 or 3 or 4; // BUSY / D3D / APRESENTAÇÃO
        return noCaption || osSaysFullscreen;
    }

    public static void VolumeStep(bool up)
    {
        byte vk = up ? (byte)0xAF : (byte)0xAE; // VK_VOLUME_UP / VK_VOLUME_DOWN
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        keybd_event(vk, 0, 2, UIntPtr.Zero);
    }
}
