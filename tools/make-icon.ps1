# Gera Assets\nook.ico (16-256 px) e Assets\nook.png a partir do desenho vetorial do ícone.
# Uso: powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$assets = Join-Path $PSScriptRoot '..\Assets'
New-Item -ItemType Directory -Force $assets | Out-Null

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-Nook([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $s = $size / 72.0
    $g.ScaleTransform($s, $s)

    # Fundo
    $bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 22, 22))
    $g.FillPath($bg, (New-RoundRect 2 2 68 68 16))

    # Canto verde (o "nook")
    $stroke = if ($size -le 24) { 6 } else { 4 }
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(30, 215, 96)), $stroke
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $corner = New-Object System.Drawing.Drawing2D.GraphicsPath
    $corner.AddLine(14, 58, 14, 40)
    $corner.AddArc(14, 14, 52, 52, 180, 90)
    $corner.AddLine(40, 14, 58, 14)
    $g.DrawPath($pen, $corner)

    # Equalizador
    $white = [System.Drawing.Brushes]::White
    $barW = if ($size -le 24) { 6 } else { 4 }
    foreach ($b in @(@(30, 38, 12), @(38, 30, 20), @(46, 40, 10))) {
        $g.FillPath($white, (New-RoundRect ($b[0] - ($barW - 4) / 2) $b[1] $barW $b[2] ($barW / 2)))
    }
    $g.Dispose()
    return $bmp
}

$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$pngs = foreach ($sz in $sizes) {
    $bmp = Draw-Nook $sz
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    if ($sz -eq 256) { $bmp.Save((Join-Path $assets 'nook.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    , $ms.ToArray()
}

# Monta o .ico (cabeçalho + diretório + PNGs embutidos)
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz = $sizes[$i]; $dim = if ($sz -ge 256) { 0 } else { $sz }
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write($p) }
[System.IO.File]::WriteAllBytes((Join-Path $assets 'nook.ico'), $out.ToArray())
Write-Output "OK: $(Join-Path $assets 'nook.ico')"
