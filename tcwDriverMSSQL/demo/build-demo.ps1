# Arma la app de ejemplo (comprobantes de la tabla dbo.Cbtes) desde TCWMsSQLDemo.txa con Clarion 11, sin abrir el IDE.
#   .\build-demo.ps1 -Conexion 'PC\INSTANCIA,base,usuario,clave'  [-Run] [-Carpeta .build2]
# La conexion (el owner de siempre: sirve para SQLMsDirectClass y para SQLMsClass) se guarda en demo\.build\TCWMsSQLDemo.ini.
param([string]$Conexion = '', [string]$ClarionRoot = 'C:\clarion11Col', [switch]$Run, [string]$Carpeta = '.build')
$ErrorActionPreference = 'Stop'
$demo = $PSScriptRoot
$root = Split-Path $demo
$out  = Join-Path $demo $Carpeta
$cl   = Join-Path $ClarionRoot 'bin\ClarionCL.exe'
$enc  = [Text.Encoding]::GetEncoding(1252)

function Invoke-CL([string[]]$a, [int]$timeout = 240) {
    $p = Start-Process $cl -ArgumentList $a -WorkingDirectory $out -NoNewWindow -PassThru `
         -RedirectStandardOutput "$out\cl.out" -RedirectStandardError "$out\cl.err"
    if (-not $p.WaitForExit($timeout * 1000)) { $p.Kill(); throw "ClarionCL $($a -join ' ') no termino (posible dialogo invisible)" }
    $text = (Get-Content "$out\cl.out" -Raw) + (Get-Content "$out\cl.err" -Raw)
    if ($text -match 'error') { Write-Host $text; throw "ClarionCL $($a[0..2] -join ' ') informo errores" }
}
function Copy-Source([string]$src, [string]$dst) {   # a cp1252 + CRLF
    $bytes = [IO.File]::ReadAllBytes($src)
    try { $t = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $t = $enc.GetString($bytes) }
    [IO.File]::WriteAllText($dst, ($t.TrimStart([char]0xFEFF) -replace "`r?`n", "`r`n"), $enc)
}

if (Test-Path $out) { Get-ChildItem $out -Exclude '*.ini' | Remove-Item -Recurse -Force }
New-Item -ItemType Directory $out -Force | Out-Null
python -I (Join-Path $demo 'make-demo-txa.py')
Copy-Source (Join-Path $demo 'TCWMsSQLDemo.txa') "$out\TCWMsSQLDemo.txa"
Get-ChildItem (Join-Path $root 'clarion') -File | ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
Copy-Item (Join-Path $ClarionRoot 'bin\Clarion110.red') $out

Write-Host '== Importando y generando' -ForegroundColor Cyan
Invoke-CL @('-win', '-au', '-ai', "$out\TCWMsSQLDemo.app", "$out\TCWMsSQLDemo.txa")
Invoke-CL @('-win', '-au', '-ag', "$out\TCWMsSQLDemo.app")
$mods = Get-ChildItem $out -Filter 'TCWMsSQLDemo*.clw'
if ($mods.Count -lt 6) { throw "Se generaron solo $($mods.Count) modulos" }

Write-Host '== Compilando' -ForegroundColor Cyan
$items = ($mods | ForEach-Object { "    <Compile Include=`"$($_.FullName)`" />" }) -join "`r`n"
@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{9D4A7C62-1E3B-4F85-A6D0-3B8E5F21C947}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>WinExe</OutputType>
    <AssemblyName>TCWMsSQLDemo</AssemblyName>
    <OutputName>TCWMsSQLDemo</OutputName>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bStringTheoryLinkMode=&gt;1%3bStringTheoryDLLMode=&gt;0</DefineConstants>
    <Model>Dll</Model>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
$items
    <FileDriver Include="MSSQL" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content "$out\TCWMsSQLDemo.cwproj" -Encoding UTF8
$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" "$out\TCWMsSQLDemo.cwproj" /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion de la demo' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaMSS.dll') $out -Force
if ($Conexion) { "[Conexion]`r`nCadena=$Conexion`r`n" | Set-Content "$out\TCWMsSQLDemo.ini" -Encoding Default }
Write-Host "`nListo: $out\TCWMsSQLDemo.exe" -ForegroundColor Green
if ($Run) { Start-Process "$out\TCWMsSQLDemo.exe" -WorkingDirectory $out }
