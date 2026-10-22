# Grava cenas do Nook em tempo real (repouso, hover, barras) para o vídeo vertical. Requer música tocando.
# Aumenta a escala do Nook durante a gravação e restaura as configurações do usuário no final.
# Uso: powershell -ExecutionPolicy Bypass -File tools\capture-reel.ps1 <pasta-de-saida>
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Rec {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out P p); public struct P { public int X, Y; }
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, int d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public static void Click() { mouse_event(2, 0, 0, 0, UIntPtr.Zero); mouse_event(4, 0, 0, 0, UIntPtr.Zero); }
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r); public struct R { public int L, T, Rr, B; }
  public static R Find(int pid) { R res = new R(); EnumWindows((h, l) => { int p; GetWindowThreadProcessId(h, out p); var sb = new System.Text.StringBuilder(64); GetWindowText(h, sb, 64); if (p == pid && IsWindowVisible(h) && sb.ToString() == "Nook") { GetWindowRect(h, out res); return false; } return true; }, IntPtr.Zero); return res; }
}
'@
[Rec]::SetProcessDPIAware() | Out-Null
$root = Split-Path $PSScriptRoot -Parent
$exe = (Get-Process Nook).Path
$cfg = "$env:APPDATA\Nook\settings.json"
$orig = Get-Content $cfg -Raw | ConvertFrom-Json   # valores do usuário, restaurados no fim
function Pump($ms) { $t = [Environment]::TickCount; while ([Environment]::TickCount - $t -lt $ms) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 5 } }
function Restart-Nook($scale, $visual, $left, $top) {
  Stop-Process -Name Nook -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 700
  $j = Get-Content $cfg -Raw | ConvertFrom-Json; $j.Scale = $scale; $j.Visual = $visual; $j.Left = $left; $j.Top = $top
  $j | ConvertTo-Json | Set-Content -Encoding utf8 $cfg
  Start-Process $exe; Start-Sleep 7
}

try {
  Restart-Nook 2.0 'Waves' 900 120
  $r = [Rec]::Find((Get-Process Nook).Id); $w = $r.Rr - $r.L; $h = $r.B - $r.T
  "player: $($r.L),$($r.T) ${w}x${h}"

  # fundo neutro atrás (sem cobrir o monitor inteiro, para não acionar o "esconder em tela cheia")
  $bw = $w + 300; $bh = $h + 400; $bx = $r.L - 150; $by = $r.T - 100
  $bg = New-Object System.Drawing.Bitmap $bw, $bh; $g = [System.Drawing.Graphics]::FromImage($bg); $g.SmoothingMode = 'AntiAlias'
  $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point $bw, $bh), ([System.Drawing.Color]::FromArgb(24, 18, 43)), ([System.Drawing.Color]::FromArgb(10, 38, 52))
  $g.FillRectangle($lg, 0, 0, $bw, $bh)
  foreach ($blob in @(@(0.55, 0.3, 420, 120, 60, 200), @(0.85, 0.25, 320, 30, 200, 120), @(0.2, 0.45, 380, 200, 60, 140))) {
    $cx = $bw * $blob[0]; $cy = $bh * $blob[1]; $rad = $blob[2]
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath; $path.AddEllipse($cx - $rad / 2, $cy - $rad / 2, $rad, $rad)
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $pg.CenterColor = [System.Drawing.Color]::FromArgb(150, $blob[3], $blob[4], $blob[5]); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $blob[3], $blob[4], $blob[5]))
    $g.FillPath($pg, $path)
  }
  $form = New-Object System.Windows.Forms.Form; $form.FormBorderStyle = 'None'; $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false
  $form.Location = New-Object System.Drawing.Point $bx, $by; $form.Size = New-Object System.Drawing.Size $bw, $bh; $form.BackgroundImage = $bg
  $form.Show(); [Rec]::SetForegroundWindow($form.Handle) | Out-Null

  $old = New-Object Rec+P; [Rec]::GetCursorPos([ref]$old) | Out-Null
  [Rec]::SetCursorPos($bx + 10, $by + $bh - 10) | Out-Null; Pump 1500
  New-Item -ItemType Directory -Force $OutDir | Out-Null

  $buf = New-Object System.Drawing.Bitmap $w, $h; $gb = [System.Drawing.Graphics]::FromImage($buf)
  function Record($label, $seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $seconds * 1000) {
      $ms = $sw.ElapsedMilliseconds
      $gb.CopyFromScreen($r.L, $r.T, 0, 0, $buf.Size)
      $buf.Save((Join-Path $OutDir ('{0}_{1:D5}.bmp' -f $label, $ms)), [System.Drawing.Imaging.ImageFormat]::Bmp)
      [System.Windows.Forms.Application]::DoEvents()
    }
  }

  Record 'idle' 3.5                                                   # vidro + ondas + título rolando
  $cover = @(($r.L + [int]($h * 0.42)), ($r.T + [int]($h * 0.42)))   # capa: sem tooltip e longe da barra de progresso
  [Rec]::SetCursorPos($cover[0], $cover[1]) | Out-Null
  Record 'hover' 3.5                                                  # nítido, título para
  [Rec]::Click(); Pump 900; [Rec]::Click(); Pump 900                  # ondas → capa → barras
  [Rec]::SetForegroundWindow($form.Handle) | Out-Null                 # garante o fundo neutro atrás de novo
  [Rec]::SetCursorPos($cover[0], $cover[1]) | Out-Null; Pump 500
  $vis = (Get-Content $cfg -Raw | ConvertFrom-Json).Visual
  if ($vis -ne 'Bars') { throw "Clique na capa não trocou para Barras (visual atual: $vis)" }
  Record 'bars' 3.5

  [Rec]::SetCursorPos($old.X, $old.Y) | Out-Null
  $form.Close()
  "quadros: $((Get-ChildItem $OutDir).Count)"
}
finally {
  Restart-Nook $orig.Scale $orig.Visual $orig.Left $orig.Top   # devolve exatamente como estava
}
