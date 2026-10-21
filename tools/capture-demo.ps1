# Grava o GIF e os prints do README (docs/). Coloca um fundo neutro atrás do Nook para não expor a área de trabalho.
# Requer: Nook rodando com música tocando, Python com Pillow.
# Uso: powershell -ExecutionPolicy Bypass -File tools\capture-demo.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Cap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out P p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, int d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public struct P { public int X, Y; }
  public static void Click() { mouse_event(2, 0, 0, 0, UIntPtr.Zero); mouse_event(4, 0, 0, 0, UIntPtr.Zero); }
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  public struct R { public int L, T, Rr, B; }
  public static R Find(int pid, string title) { R res = new R(); EnumWindows((h, l) => { int p; GetWindowThreadProcessId(h, out p); var sb = new System.Text.StringBuilder(64); GetWindowText(h, sb, 64); if (p == pid && IsWindowVisible(h) && sb.ToString().StartsWith(title)) { GetWindowRect(h, out res); return false; } return true; }, IntPtr.Zero); return res; }
}
'@
[Cap]::SetProcessDPIAware() | Out-Null

$root = Split-Path $PSScriptRoot -Parent
$docs = Join-Path $root 'docs'; $frames = Join-Path $env:TEMP 'nook-frames'
New-Item -ItemType Directory -Force $docs | Out-Null
Remove-Item -Recurse -Force $frames -ErrorAction SilentlyContinue; New-Item -ItemType Directory $frames | Out-Null

$nook = Get-Process Nook
$r = [Cap]::Find($nook.Id, 'Nook')
$pad = 36

# Fundo neutro (gradiente com manchas de cor, para o vidro fosco aparecer) — não cobre o monitor inteiro
$bw = 760; $bh = 820
$bx = [Math]::Max(0, $r.L - ($bw - ($r.Rr - $r.L)) + 30); $by = [Math]::Max(0, $r.T - 40)
$bg = New-Object System.Drawing.Bitmap $bw, $bh
$g = [System.Drawing.Graphics]::FromImage($bg); $g.SmoothingMode = 'AntiAlias'
$lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point $bw, $bh), ([System.Drawing.Color]::FromArgb(24, 18, 43)), ([System.Drawing.Color]::FromArgb(10, 38, 52))
$g.FillRectangle($lg, 0, 0, $bw, $bh)
foreach ($blob in @(@(0.62, 0.05, 260, 120, 60, 200), @(0.85, 0.02, 200, 30, 200, 120), @(0.2, 0.4, 320, 200, 60, 140), @(0.7, 0.6, 280, 40, 120, 220))) {
  $cx = $bw * $blob[0]; $cy = $bh * $blob[1]; $rad = $blob[2]
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath; $path.AddEllipse($cx - $rad / 2, $cy - $rad / 2, $rad, $rad)
  $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
  $pg.CenterColor = [System.Drawing.Color]::FromArgb(150, $blob[3], $blob[4], $blob[5]); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $blob[3], $blob[4], $blob[5]))
  $g.FillPath($pg, $path)
}
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'; $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false
$form.Location = New-Object System.Drawing.Point $bx, $by; $form.Size = New-Object System.Drawing.Size $bw, $bh
$form.BackgroundImage = $bg
$form.Show(); [Cap]::SetForegroundWindow($form.Handle) | Out-Null

function Pump($ms) { $t = [Environment]::TickCount; while ([Environment]::TickCount - $t -lt $ms) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 } }
function Grab($x, $y, $w, $h, $path) { $b = New-Object System.Drawing.Bitmap $w, $h; $gg = [System.Drawing.Graphics]::FromImage($b); $gg.CopyFromScreen($x, $y, 0, 0, $b.Size); $b.Save($path); $gg.Dispose(); $b.Dispose() }

$old = New-Object Cap+P; [Cap]::GetCursorPos([ref]$old) | Out-Null
[Cap]::SetCursorPos($bx + 20, $by + $bh - 20) | Out-Null   # cursor longe do player
Pump 1500

$x = $r.L - $pad; $y = $r.T - $pad; $w = $r.Rr - $r.L + 2 * $pad; $h = $r.B - $r.T + 2 * $pad
$n = 0
function Burst($count) { for ($i = 0; $i -lt $count; $i++) { Grab $x $y $w $h (Join-Path $frames ('f{0:D4}.png' -f $script:n)); $script:n++; Pump 60 } }

Burst 70                                                   # repouso: vidro + ondas + título rolando
Grab $x $y $w $h (Join-Path $docs 'shot-idle.png')
[Cap]::SetCursorPos($r.L + 200, $r.B - 12) | Out-Null; Pump 400
Burst 30                                                   # hover: nítido, título para
Grab $x $y $w $h (Join-Path $docs 'shot-hover.png')
[Cap]::SetCursorPos($r.L + 32, $r.T + 34) | Out-Null; Pump 300
[Cap]::Click(); Pump 900; [Cap]::Click(); Pump 900       # ondas → capa → barras
Burst 40                                                   # clique na capa: barras
Grab $x $y $w $h (Join-Path $docs 'shot-bars.png')
[Cap]::Click(); Pump 900                                  # barras → ondas (volta ao normal)

# Menu de configurações (duplo clique)
[Cap]::SetCursorPos($r.L + 200, $r.B - 12) | Out-Null; Pump 300; [Cap]::Click(); Pump 90; [Cap]::Click(); Pump 1200
$s = [Cap]::Find($nook.Id, "Nook $([char]0xB7)")
if ($s.Rr -gt 0) { Grab ($s.L - 24) ($s.T - 24) ($s.Rr - $s.L + 48) ($s.B - $s.T + 48) (Join-Path $docs 'shot-settings.png') }
[System.Windows.Forms.SendKeys]::SendWait('{ESC}'); Pump 400

[Cap]::SetCursorPos($old.X, $old.Y) | Out-Null
$form.Close(); $form.Dispose()

python (Join-Path $PSScriptRoot 'frames-to-gif.py') $frames (Join-Path $docs 'demo.gif')
Remove-Item -Recurse -Force $frames
