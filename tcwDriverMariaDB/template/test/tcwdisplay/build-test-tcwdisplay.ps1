# Prueba de TCW_Display.tpl con File of procedure = SQLCLASS MariaDB / SQLCLASS MSSQL, sin tocar la instalacion:
# usa .test-<motor> con su propio Clarion110.red y una copia del registro de templates (el TCW_Display nuevo se
# registra en la copia). La app NO tiene la extension global de SQLClass: el template tiene que agregar todo solo.
#   .\build-test-tcwdisplay.ps1 -Motor MariaDB -Conexion 'Server=...;Port=3306;Database=...;User=...;Password=...'
#   .\build-test-tcwdisplay.ps1 -Motor MSSQL   -Conexion 'servidor,base,usuario,clave'
# -Heredar: la app lleva la extension global SQLClass (objeto SQLG que se conecta solo) y el procedimiento deja
# Conexion vacia: tiene que conectarse con SQLG.PropOwner.
# Compila con las clases del proyecto (..\..\..\clarion, ..\..\..\sqlclass6, ..\..\..\..\tcwDriverMSSQL\clarion).
param([Parameter(Mandatory)][ValidateSet('MariaDB', 'MSSQL')][string]$Motor,
      [Parameter(Mandatory)][string]$Conexion,
      [switch]$Heredar,
      [string]$ClarionRoot = 'C:\clarion11Col',
      [string]$Template = (Join-Path $PSScriptRoot '..\..\..\..\TCW_DirectX\TCW_Display.tpl'))
$ErrorActionPreference = 'Stop'
$test = $PSScriptRoot
$root = (Resolve-Path (Join-Path $test '..\..\..')).Path
$out  = Join-Path $test (".test-$Motor" + $(if ($Heredar) { '-heredar' } else { '' }))
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

# entorno aislado: red propio + copia del registro + TCW_Display nuevo registrado ahi
$registryOriginal = Join-Path $ClarionRoot 'template\win\TemplateRegistry11.trf'
$hashAntes = (Get-FileHash $registryOriginal).Hash
New-Item -ItemType Directory $out -Force | Out-Null
Get-ChildItem $out -Exclude '*.trf' | Remove-Item -Recurse -Force
if (-not (Test-Path "$out\TemplateRegistry11.trf")) { Copy-Item $registryOriginal $out }
$red = (Get-Content (Join-Path $ClarionRoot 'bin\Clarion110.red')) `
       -replace '^\*\.tp\? = %ROOT%\\template\\win$', "*.tp? = $out;%ROOT%\template\win" `
       -replace '^\*\.trf = .*$', "*.trf = $out"
$red | Set-Content "$out\Clarion110.red" -Encoding Default
Copy-Item $Template "$out\TCW_Display.tpl"
Write-Host '== Registrando TCW_Display en la copia del registro' -ForegroundColor Cyan
Invoke-CL @('-win', '-tr', "$out\TCW_Display.tpl")
if ($Heredar) {
    Copy-Item (Join-Path $root 'template\sqlclass6.tpl') "$out\sqlclass6.tpl"
    Invoke-CL @('-win', '-tr', "$out\sqlclass6.tpl")
}

python -I (Join-Path $test 'make-tcwtest-txa.py') $Motor "$out\TcwTest.txa" $(if ($Heredar) { 'heredar' } else { '' })
if ($LASTEXITCODE) { throw 'Fallo make-tcwtest-txa.py' }
foreach ($d in 'clarion', 'sqlclass6', '..\tcwDriverMSSQL\clarion') {
    Get-ChildItem (Join-Path $root $d) -File | ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
}
Copy-Item (Join-Path $ClarionRoot 'accessory\images\*.ico') $out -ErrorAction SilentlyContinue
if (-not (Test-Path "$out\ps.ico")) { Get-ChildItem (Join-Path $ClarionRoot 'images') -Filter *.ico | Select-Object -First 1 | Copy-Item -Destination "$out\ps.ico" }
Write-Host '== Importando y generando' -ForegroundColor Cyan
Invoke-CL @('-win', '-au', '-ai', "$out\TcwTest.app", "$out\TcwTest.txa")
Invoke-CL @('-win', '-au', '-ag', "$out\TcwTest.app")
$mods = Get-ChildItem $out -Filter 'TcwTe*.clw'
Write-Host ("   modulos: " + (($mods | ForEach-Object Name) -join ', '))

# lo que el template tuvo que agregar solo
$clase = if ($Motor -eq 'MSSQL') { 'SQLMsDirectClass' } else { 'SQLMariaClass' }
$inc   = if ($Motor -eq 'MSSQL') { 'SQLClass6MsDirect.inc' } else { 'SQLClass6Maria.inc' }
$gen   = ($mods | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
$app   = $enc.GetString([IO.File]::ReadAllBytes("$out\TcwTest.app"))
$chk = [ordered]@{
    "instancia local SQLD $clase" = $gen -match "SQLD\s+$clase"
    "INCLUDE('$inc')"             = $gen.Contains("INCLUDE('$inc')")
    'conecta en Init'             = $gen -match $(if ($Heredar) { 'SQLD\.Init(Maria|Direct)\(SQLG\.PropOwner\)' } else { 'SQLD\.Init(Maria|Direct)\(GETINI' })
    'revisa el error de Exec'     = $gen.Contains('SQLD.ErrorText()')
    'SQLClass6SinStringTheory'    = $app.Contains('SQLClass6SinStringTheory')
}
if ($Motor -eq 'MariaDB') { $chk['libmariadb.lib en el proyecto'] = $app.Contains('libmariadb.lib') }
$chk.GetEnumerator() | ForEach-Object { Write-Host ("   {0,-5} {1}" -f $_.Value, $_.Key) }
if ($chk.Values -contains $false) { throw 'El codigo generado no tiene todo lo esperado' }

Write-Host '== Compilando' -ForegroundColor Cyan
$items = ($mods | ForEach-Object { "    <Compile Include=`"$($_.FullName)`" />" }) -join "`r`n"
$lib   = if ($Motor -eq 'MariaDB') { '<Library Include="libmariadb.lib" />' } else { '' }
@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{3C9A1E52-6B4D-4F80-A2E7-91D5C0B8F613}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>WinExe</OutputType>
    <AssemblyName>TcwTest</AssemblyName>
    <OutputName>TcwTest</OutputName>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bSQLClass6SinStringTheory=&gt;1</DefineConstants>
    <Model>Dll</Model>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
$items
    $lib
    $(if ($Heredar) { '<FileDriver Include="' + $(if ($Motor -eq 'MSSQL') { 'MSSQL' } else { 'ODBC' }) + '" />' })
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content "$out\TcwTest.cwproj" -Encoding UTF8
if ($Motor -eq 'MariaDB') { Copy-Item (Join-Path $root 'lib\libmariadb.lib'), (Join-Path $root 'bin\libmariadb.dll') $out -Force }
$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
$build = & "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" "$out\TcwTest.cwproj" /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { $build | Where-Object { $_ -match 'error' } | Write-Host; throw 'Fallo la compilacion de la prueba' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaODB.dll'), (Join-Path $ClarionRoot 'bin\ClaMSS.dll') $out -Force
"[Conexion]`r`nCadena=$Conexion`r`n" | Set-Content "$out\TcwTest.ini" -Encoding Default

Write-Host '== Ejecutando' -ForegroundColor Cyan
$p = Start-Process "$out\TcwTest.exe" -WorkingDirectory $out -PassThru
if (-not $p.WaitForExit(90000)) { $p.Kill(); throw 'TcwTest.exe no termino' }
Get-Content "$out\resultado.txt" -Encoding Default
if ((Get-FileHash $registryOriginal).Hash -ne $hashAntes) { throw 'El registro de templates de la instalacion cambio' }
Write-Host 'Registro de templates de la instalacion: sin cambios' -ForegroundColor Green
