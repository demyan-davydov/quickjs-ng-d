# Builds the vendored QuickJS-NG (+ ABI probe) into build\lib\quickjs-ng.lib with MSVC (cl/lib).
# Run from a Developer PowerShell / after vcvars64. Honors $env:CFLAGS. Compiled with /MT to match
# LDC's default static CRT; verified in CI on windows-latest (x86_64, MSVC).
param([string]$Mode = "static")
$ErrorActionPreference = "Stop"
if ($Mode -ne "static") { throw "only 'static' is implemented on Windows" }

$Root = Split-Path -Parent $PSScriptRoot
$Src  = Join-Path $Root "vendor\quickjs-ng"
$Out  = Join-Path $Root "build\lib"
$Obj  = Join-Path $Root "build\obj-$Mode"
New-Item -ItemType Directory -Force $Out, $Obj | Out-Null

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw "cl.exe not found: run from a Visual Studio developer environment (vcvars64.bat)"
}

$Flags = @("/nologo", "/O2", "/std:c11", "/experimental:c11atomics", "/J", "/MT",
           "/DQUICKJS_NG_BUILD", "/DWIN32_LEAN_AND_MEAN", "/D_WIN32_WINNT=0x0601",
           "/wd4018", "/wd4061", "/wd4100", "/wd4146", "/wd4244", "/wd4267", "/wd4334", "/wd4996",
           "/I$Src")
if ($env:CFLAGS) { $Flags += $env:CFLAGS -split " " }

$Sources = @("$Src\quickjs.c", "$Src\libregexp.c", "$Src\libunicode.c", "$Src\dtoa.c", "$Root\abi\abi_probe.c")
$Target  = Join-Path $Out "quickjs-ng.lib"
$Stamp   = Join-Path $Obj "flags.stamp"
# cl.exe prints its banner to stderr; read it through cmd so $ErrorActionPreference=Stop is not triggered
$ClVersion = (& cmd.exe /c "cl.exe 2>&1" | Select-Object -First 1)
$NewStamp = "$ClVersion" + "|" + ($Flags -join " ")
if (-not (Test-Path $Stamp) -or (Get-Content $Stamp -Raw) -ne $NewStamp) {
    Remove-Item "$Obj\*.obj", $Target -ErrorAction SilentlyContinue
    Set-Content $Stamp $NewStamp -NoNewline
}

$Headers = Get-ChildItem "$Src\*.h"
$NeedLink = -not (Test-Path $Target)
foreach ($s in $Sources) {
    $o = Join-Path $Obj ([IO.Path]::GetFileNameWithoutExtension($s) + ".obj")
    $rebuild = -not (Test-Path $o)
    if (-not $rebuild) {
        $t = (Get-Item $o).LastWriteTime
        $rebuild = ((Get-Item $s).LastWriteTime -gt $t) -or ($Headers | Where-Object { $_.LastWriteTime -gt $t })
    }
    if ($rebuild) {
        Write-Host "CC  $(Split-Path -Leaf $s)"
        & cl.exe @Flags /c $s "/Fo$o"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $NeedLink = $true
    }
}
if ($NeedLink) {
    Write-Host "LIB quickjs-ng.lib"
    Remove-Item $Target -ErrorAction SilentlyContinue
    & lib.exe /nologo "/OUT:$Target" (Get-ChildItem "$Obj\*.obj" | ForEach-Object FullName)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
