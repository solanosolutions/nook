# Gera o Nook.exe independente (self-contained): roda em qualquer Windows 10/11 x64 sem instalar o .NET.
# Padrão: comprimido (~74 MB, abre ~0,6 s mais devagar). -NoCompress: ~179 MB, abre um pouco mais rápido.
# Uso: powershell -ExecutionPolicy Bypass -File tools\publish.ps1 [-NoCompress]
param([switch]$NoCompress)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$version = ([xml](Get-Content (Join-Path $root 'Nook.csproj'))).Project.PropertyGroup.Version | Where-Object { $_ } | Select-Object -First 1
$suffix = if ($NoCompress) { '-full' } else { '' }
$out = Join-Path $root "release\v$version$suffix"

$env:PATH += ";C:\Program Files\dotnet"
dotnet publish (Join-Path $root 'Nook.csproj') -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=$((-not $NoCompress).ToString().ToLower()) `
    -p:DebugType=none `
    -o $out -nologo -v q
if ($LASTEXITCODE -ne 0) { throw "Falha no build" }

$exe = Join-Path $out 'Nook.exe'
"OK: $exe ($([math]::Round((Get-Item $exe).Length / 1MB, 1)) MB)"
