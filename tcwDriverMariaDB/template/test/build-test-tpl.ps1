# Prueba del template sqlclass6.tpl con la opcion Motor, sin tocar la instalacion de Clarion:
# usa template\.test con su propio Clarion110.red (*.trf y *.tp? apuntan ahi) y una copia del registro de templates.
#   .\build-test-tpl.ps1 [-Conexion 'Server=...;Database=...;User=...;Password=...'] [-SinStringTheory]
#   .\build-test-tpl.ps1 -Motor MSSQL -Conexion 'servidor,base,usuario,clave'   (SqlTestMs.txa: driver MSSQL + SQL Server directo)
# Compila con la SQLClass6 del proyecto (..\..\sqlclass6), no con la instalada.
param([string]$Conexion = '', [string]$ClarionRoot = 'C:\clarion11Col', [switch]$SinStringTheory,
      [ValidateSet('MariaDB', 'MSSQL')][string]$Motor = 'MariaDB')
$ErrorActionPreference = 'Stop'
$test = $PSScriptRoot
$tpl  = Split-Path $test
$root = Split-Path $tpl
$out  = Join-Path $tpl '.test'
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

# entorno aislado: red propio + copia del registro + template nuevo registrado ahi
$registryOriginal = Join-Path $ClarionRoot 'template\win\TemplateRegistry11.trf'
$hashAntes = (Get-FileHash $registryOriginal).Hash
New-Item -ItemType Directory $out -Force | Out-Null
Get-ChildItem $out -Exclude '*.trf', '*.ini' | Remove-Item -Recurse -Force
if (-not (Test-Path "$out\TemplateRegistry11.trf")) { Copy-Item $registryOriginal $out }
$red = (Get-Content (Join-Path $ClarionRoot 'bin\Clarion110.red')) `
       -replace '^\*\.tp\? = %ROOT%\\template\\win$', "*.tp? = $out;%ROOT%\template\win" `
       -replace '^\*\.trf = .*$', "*.trf = $out"
$red | Set-Content "$out\Clarion110.red" -Encoding Default
Copy-Item (Join-Path $tpl 'sqlclass6.tpl') $out
Write-Host '== Registrando el template en la copia del registro' -ForegroundColor Cyan
Invoke-CL @('-win', '-tr', "$out\sqlclass6.tpl")

$txa = if ($Motor -eq 'MSSQL') { 'SqlTestMs.txa' } else { 'SqlTest.txa' }
Copy-Source (Join-Path $test $txa) "$out\SqlTest.txa"
if ($SinStringTheory) {   # check 'Usar StringTheory' destildado
    $t = [IO.File]::ReadAllText("$out\SqlTest.txa", $enc) -replace "(%QFieldSize DEFAULT  \('50'\)\r\n)", "`$1%QUsaStringTheory LONG  (0)`r`n"
    [IO.File]::WriteAllText("$out\SqlTest.txa", $t, $enc)
}
Get-ChildItem (Join-Path $root 'sqlclass6') -File | ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
Get-ChildItem (Join-Path $root 'clarion'), (Join-Path $root '..\tcwDriverMSSQL\clarion') -File |
    ForEach-Object { Copy-Source $_.FullName (Join-Path $out $_.Name) }
Write-Host '== Importando y generando' -ForegroundColor Cyan
Invoke-CL @('-win', '-au', '-ai', "$out\SqlTest.app", "$out\SqlTest.txa")
Invoke-CL @('-win', '-au', '-ag', "$out\SqlTest.app")
$mods = Get-ChildItem $out -Filter 'SqlTe*.clw'
Write-Host ("   modulos: " + (($mods | ForEach-Object Name) -join ', '))

Write-Host '== Compilando' -ForegroundColor Cyan
$defines = '_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bStringTheoryLinkMode=&gt;1%3bStringTheoryDLLMode=&gt;0'
if ($SinStringTheory) {
    if (-not (Select-String "$out\SqlTest.app" -Pattern 'SQLClass6SinStringTheory' -SimpleMatch -Quiet)) {
        throw 'El template no agrego SQLClass6SinStringTheory al proyecto de la app'
    }
    Write-Host '   el template agrego SQLClass6SinStringTheory al proyecto de la app'
    $defines = '_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bSQLClass6SinStringTheory=&gt;1'
}
$items = ($mods | ForEach-Object { "    <Compile Include=`"$($_.FullName)`" />" }) -join "`r`n"
@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{8E2D4C61-7A35-4B0F-9D18-C3A5E6F70B42}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>WinExe</OutputType>
    <AssemblyName>SqlTest</AssemblyName>
    <OutputName>SqlTest</OutputName>
    <DefineConstants>$defines</DefineConstants>
    <Model>Dll</Model>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
$items
    <Library Include="libmariadb.lib" />
    <FileDriver Include="$(if ($Motor -eq 'MSSQL') { 'MSSQL' } else { 'ODBC' })" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content "$out\SqlTest.cwproj" -Encoding UTF8
Copy-Item (Join-Path $root 'lib\libmariadb.lib'), (Join-Path $root 'bin\libmariadb.dll') $out -Force
$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" "$out\SqlTest.cwproj" /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion de la prueba' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaODB.dll'), (Join-Path $ClarionRoot 'bin\ClaMSS.dll') $out -Force
if ($Conexion) { "[Conexion]`r`nCadena=$Conexion`r`n" | Set-Content "$out\SqlTest.ini" -Encoding Default }

Write-Host '== Ejecutando' -ForegroundColor Cyan
Remove-Item "$out\resultado.txt" -ErrorAction SilentlyContinue
$p = Start-Process "$out\SqlTest.exe" -WorkingDirectory $out -PassThru
if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'SqlTest.exe no termino' }
Get-Content "$out\resultado.txt" -Encoding Default
if ((Get-FileHash $registryOriginal).Hash -ne $hashAntes) { throw 'El registro de templates de la instalacion cambio' }
Write-Host 'Registro de templates de la instalacion: sin cambios' -ForegroundColor Green
