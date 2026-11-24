# Banco de sqlclass6.tpl v6.4 + TCW_Display.tpl 1.9.4 (11/11/2026): objeto SQL siempre con el driver de la app,
# Conexion, y File of procedure SQLCLASS / SQLCLASS MSSQL. Multi-DLL: SqDat.dll (duena de SQL y SQLD) + TcwEx.exe
# (datos externos, un TCW_Display por caso) y SqDaB.dll (Conexion = Glo:OwnerName). Solo genera y compila.
# Aislado como build-test-tcwdisplay.ps1: .test-conexion con su Clarion110.red y una COPIA del registro de templates;
# al final comprueba que el registro de la instalacion no cambio.
#   .\build-test-conexion.ps1 [-ClarionRoot C:\clarion11Col]
param([string]$ClarionRoot = 'C:\clarion11Col',
      [string]$TplDisplay = (Join-Path $PSScriptRoot '..\..\..\..\..\TCW\TCW_DirectX\TCW_Display.tpl'),
      [string]$TplSqlClass = (Join-Path $PSScriptRoot '..\..\sqlclass6.tpl'))
$ErrorActionPreference = 'Stop'
$test = $PSScriptRoot
$root = (Resolve-Path (Join-Path $test '..\..\..')).Path
$out  = Join-Path $test '.test-conexion'
$cl   = Join-Path $ClarionRoot 'bin\ClarionCL.exe'
$enc  = [Text.Encoding]::GetEncoding(1252)

function Invoke-CL([string[]]$a, [int]$timeout = 240) {
    $p = Start-Process $cl -ArgumentList $a -WorkingDirectory $out -NoNewWindow -PassThru `
         -RedirectStandardOutput "$out\cl.out" -RedirectStandardError "$out\cl.err"
    if (-not $p.WaitForExit($timeout * 1000)) { $p.Kill(); throw "ClarionCL $($a -join ' ') no termino (posible dialogo invisible)" }
    $text = (Get-Content "$out\cl.out" -Raw) + (Get-Content "$out\cl.err" -Raw)
    Add-Content "$out\cl.log" "== $($a -join ' ')`r`n$text"
    if ($text -match 'error') { Write-Host $text; throw "ClarionCL $($a[0..2] -join ' ') informo errores" }
}
function Copy-Source([string]$src, [string]$dst) {   # a cp1252 + CRLF
    $bytes = [IO.File]::ReadAllBytes($src)
    try { $t = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $t = $enc.GetString($bytes) }
    [IO.File]::WriteAllText($dst, ($t.TrimStart([char]0xFEFF) -replace "`r?`n", "`r`n"), $enc)
}

$registryOriginal = Join-Path $ClarionRoot 'template\win\TemplateRegistry11.trf'
$hashAntes = (Get-FileHash $registryOriginal).Hash
New-Item -ItemType Directory $out -Force | Out-Null
Get-ChildItem $out | Remove-Item -Recurse -Force
Copy-Item $registryOriginal $out
$red = (Get-Content (Join-Path $ClarionRoot 'bin\Clarion110.red')) `
       -replace '^\*\.tp\? = %ROOT%\\template\\win$', "*.tp? = $out;%ROOT%\template\win" `
       -replace '^\*\.trf = .*$', "*.trf = $out"
$red | Set-Content "$out\Clarion110.red" -Encoding Default
Copy-Item $TplDisplay "$out\TCW_Display.tpl"
Copy-Item $TplSqlClass "$out\sqlclass6.tpl"
Write-Host '== Registrando TCW_Display y sqlclass6 en la copia del registro' -ForegroundColor Cyan
Invoke-CL @('-win', '-tr', "$out\TCW_Display.tpl")
Invoke-CL @('-win', '-tr', "$out\sqlclass6.tpl")

python -I (Join-Path $test 'make-conexion-txa.py') $out
if ($LASTEXITCODE) { throw 'Fallo make-conexion-txa.py' }
foreach ($d in 'sqlclass6', '..\tcwDriverMSSQL\clarion') {
    Get-ChildItem (Join-Path $root $d) -File | ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
}
Copy-Item (Join-Path $ClarionRoot 'accessory\images\*.ico') $out -ErrorAction SilentlyContinue
if (-not (Test-Path "$out\ps.ico")) { Get-ChildItem (Join-Path $ClarionRoot 'images') -Filter *.ico | Select-Object -First 1 | Copy-Item -Destination "$out\ps.ico" }

foreach ($a in 'SqDat', 'SqDaB', 'TcwEx') {
    Write-Host "== Importando y generando $a" -ForegroundColor Cyan
    Invoke-CL @('-win', '-au', '-ai', "$out\$a.app", "$out\$a.txa")
    Invoke-CL @('-win', '-au', '-ag', "$out\$a.app")
}
if ((Get-FileHash $registryOriginal).Hash -ne $hashAntes) { throw 'El registro de templates de la instalacion cambio' }
Write-Host 'Registro de templates de la instalacion: sin cambios' -ForegroundColor Green

function Build([string]$name, [bool]$dll) {
    $mods = Get-ChildItem $out -Filter "$name*.clw"
    $items = ($mods | ForEach-Object { "    <Compile Include=`"$($_.Name)`" />" }) -join "`r`n"
    $defs = if ($dll) { 'maincode=&gt;off%3b_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bSQLClass6SinStringTheory=&gt;1' } `
            else      { '_ABCDllMode_=&gt;1%3b_ABCLinkMode_=&gt;0%3bSQLClass6SinStringTheory=&gt;1' }
    $libs = if ($dll) { '' } else { '<Library Include="SqDat.lib" />' }
@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{$([guid]::NewGuid().ToString().ToUpper())}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>$(if ($dll) { 'Library' } else { 'WinExe' })</OutputType>
    <AssemblyName>$name</AssemblyName>
    <OutputName>$name</OutputName>
    <DefineConstants>$defs</DefineConstants>
    <Model>Dll</Model>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
$items
    $libs
    <FileDriver Include="MSSQL" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content "$out\$name.cwproj" -Encoding UTF8
    Write-Host "== Compilando $name ($(($mods | ForEach-Object Name) -join ', '))" -ForegroundColor Cyan
    $env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
    $build = & "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" "$out\$name.cwproj" /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
    $build | Set-Content "$out\$name.build.log"
    if ($LASTEXITCODE) { $build | Where-Object { $_ -match 'error' } | Write-Host; Write-Host "FALLO la compilacion de $name" -ForegroundColor Red }
    else { Write-Host "   $name compilado" -ForegroundColor Green }
}
Build 'SqDat' $true
Build 'SqDaB' $true
Build 'TcwEx' $false
