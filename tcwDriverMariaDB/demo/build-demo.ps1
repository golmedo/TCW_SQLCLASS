# Arma la app de ejemplo (comprobantes de la tabla cbtes) desde TCWMariaDemo.txa con Clarion 11, sin abrir el IDE.
#   .\build-demo.ps1 -Conexion 'Server=localhost;Port=3306;Database=gestion;User=root;Password=...'  [-Run]
# La conexion se guarda en demo\.build\TCWMariaDemo.ini (no queda en el codigo).
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
Copy-Source (Join-Path $demo 'TCWMariaDemo.txa') "$out\TCWMariaDemo.txa"
Get-ChildItem (Join-Path $root 'clarion') -File | ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
Copy-Item (Join-Path $ClarionRoot 'bin\Clarion110.red') $out

Write-Host '== Importando y generando' -ForegroundColor Cyan
Invoke-CL @('-win', '-au', '-ai', "$out\TCWMariaDemo.app", "$out\TCWMariaDemo.txa")
Invoke-CL @('-win', '-au', '-ag', "$out\TCWMariaDemo.app")
$mods = Get-ChildItem $out -Filter 'TCWMariaDemo*.clw'
if ($mods.Count -lt 5) { throw "Se generaron solo $($mods.Count) modulos" }

Write-Host '== Compilando' -ForegroundColor Cyan
$items = ($mods | ForEach-Object { "    <Compile Include=`"$($_.FullName)`" />" }) -join "`r`n"
@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{5A7C3E19-2B84-4D6F-9C0E-81F4B2A6D3E7}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>WinExe</OutputType>
    <AssemblyName>TCWMariaDemo</AssemblyName>
    <OutputName>TCWMariaDemo</OutputName>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bStringTheoryLinkMode=&gt;1%3bStringTheoryDLLMode=&gt;0</DefineConstants>
    <Model>Dll</Model>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
$items
    <Library Include="libmariadb.lib" />
    <FileDriver Include="ODBC" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content "$out\TCWMariaDemo.cwproj" -Encoding UTF8
Copy-Item (Join-Path $root 'lib\libmariadb.lib'), (Join-Path $root 'bin\libmariadb.dll') $out -Force
$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" "$out\TCWMariaDemo.cwproj" /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion de la demo' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaODB.dll') $out -Force
if ($Conexion) { "[Conexion]`r`nCadena=$Conexion`r`n" | Set-Content "$out\TCWMariaDemo.ini" -Encoding Default }
Write-Host "`nListo: $out\TCWMariaDemo.exe" -ForegroundColor Green
if ($Run) { Start-Process "$out\TCWMariaDemo.exe" -WorkingDirectory $out }
