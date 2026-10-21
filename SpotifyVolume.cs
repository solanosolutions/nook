using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Nook;

/// <summary>
/// Ajusta o volume só do Spotify no mixer do Windows (sessões de áudio do Core Audio),
/// sem mexer no volume geral do PC.
/// </summary>
static class SpotifyVolume
{
    /// <summary>Soma delta (-1..1) ao volume do Spotify. Retorna false se não achou a sessão dele.</summary>
    public static bool TryStep(float delta, out int percent)
    {
        percent = 0;
        var pids = new HashSet<uint>();
        foreach (var p in Process.GetProcessesByName("Spotify")) { pids.Add((uint)p.Id); p.Dispose(); }
        if (pids.Count == 0) return false;

        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        try
        {
            enumerator.GetDefaultAudioEndpoint(0 /* render */, 1 /* multimedia */, out IMMDevice device);
            var iid = typeof(IAudioSessionManager2).GUID;
            device.Activate(ref iid, 23 /* CLSCTX_ALL */, IntPtr.Zero, out object mgrObj);
            var manager = (IAudioSessionManager2)mgrObj;
            manager.GetSessionEnumerator(out IAudioSessionEnumerator sessions);
            sessions.GetCount(out int count);

            bool found = false;
            float target = 0;
            for (int i = 0; i < count; i++)
            {
                sessions.GetSession(i, out object session);
                try
                {
                    ((IAudioSessionControl2)session).GetProcessId(out uint pid);
                    if (!pids.Contains(pid)) continue;

                    var volume = (ISimpleAudioVolume)session;
                    if (!found)
                    {
                        volume.GetMasterVolume(out float current);
                        target = Math.Clamp(current + delta, 0f, 1f);
                        found = true;
                    }
                    var ctx = Guid.Empty;
                    volume.SetMasterVolume(target, ref ctx); // Spotify pode ter mais de uma sessão: todas iguais
                }
                catch { }
                finally { Marshal.ReleaseComObject(session); }
            }
            Marshal.ReleaseComObject(sessions);
            Marshal.ReleaseComObject(manager);
            Marshal.ReleaseComObject(device);
            percent = (int)Math.Round(target * 100);
            return found;
        }
        finally { Marshal.ReleaseComObject(enumerator); }
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorCom { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        void EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        void GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        void Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    }

    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionManager2
    {
        void GetAudioSessionControl(IntPtr sessionGuid, int flags, out IntPtr control);
        void GetSimpleAudioVolume(IntPtr sessionGuid, int flags, out IntPtr volume);
        void GetSessionEnumerator(out IAudioSessionEnumerator sessions);
    }

    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionEnumerator
    {
        void GetCount(out int count);
        void GetSession(int index, [MarshalAs(UnmanagedType.IUnknown)] out object session);
    }

    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl2
    {
        // IAudioSessionControl
        void GetState(out int state);
        void GetDisplayName(out IntPtr name);
        void SetDisplayName(IntPtr name, IntPtr ctx);
        void GetIconPath(out IntPtr path);
        void SetIconPath(IntPtr path, IntPtr ctx);
        void GetGroupingParam(out Guid param);
        void SetGroupingParam(IntPtr param, IntPtr ctx);
        void RegisterAudioSessionNotification(IntPtr client);
        void UnregisterAudioSessionNotification(IntPtr client);
        // IAudioSessionControl2
        void GetSessionIdentifier(out IntPtr id);
        void GetSessionInstanceIdentifier(out IntPtr id);
        void GetProcessId(out uint pid);
    }

    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ISimpleAudioVolume
    {
        void SetMasterVolume(float level, ref Guid ctx);
        void GetMasterVolume(out float level);
    }
}
