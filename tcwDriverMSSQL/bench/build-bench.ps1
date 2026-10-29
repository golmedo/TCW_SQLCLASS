# Compila la prueba de velocidad (BenchMSSQL.clw + tcwodbc.c) con Clarion 11 en bench\.build y, con -Run, la ejecuta.
#   .\build-bench.ps1 -Servidor 'PC\INSTANCIA' -Base psnamen -Usuario sa -Clave '...' -Run
# La conexion se guarda en bench\.build\bench.ini (no queda en el codigo ni en git).
# Usa la SQLClass6 extendida de ..\..\tcwDriverMariaDB\sqlclass6 (ExecEx) sin StringTheory.
param([string]$Servidor = '', [string]$Base = '', [string]$Usuario = '', [string]$Clave = '',
      [string]$DriverOdbc = 'ODBC Driver 17 for SQL Server', [int]$Corridas = 3,
      [string]$ClarionRoot = 'C:\clarion11Col', [switch]$Run, [switch]$Detalle)
$ErrorActionPreference = 'Stop'
$bench = $PSScriptRoot
$out   = Join-Path $bench '.build'
$enc   = [Text.Encoding]::GetEncoding(1252)
New-Item -ItemType Directory $out -Force | Out-Null

# fuentes en cp1252 y CRLF (el compilador de Clarion no acepta LF solo)
$sqlclass6 = Join-Path $bench '..\..\tcwDriverMariaDB\sqlclass6'
foreach ($f in @(Get-Item (Join-Path $bench 'BenchMSSQL.clw'), (Join-Path $bench 'tcwodbc.c')) + @(Get-ChildItem $sqlclass6 -File) +
             @(Get-ChildItem (Join-Path $bench '..\clarion') -File)) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    try { $t = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $t = $enc.GetString($bytes) }
    $t = $t.TrimStart([char]0xFEFF) -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText((Join-Path $out $f.Name), $t, $enc)
}

@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{3C6D9A41-7E25-4B80-9F1D-52A8E0C4B7D3}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Release</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>Exe</OutputType>
    <AssemblyName>BenchMSSQL</AssemblyName>
    <OutputName>BenchMSSQL</OutputName>
    <Model>Dll</Model>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bSQLClass6SinStringTheory=&gt;1</DefineConstants>
  </PropertyGroup>
  <ItemGroup>
    <FileDriver Include="ASCII" />
    <FileDriver Include="MSSQL" />
    <Compile Include="$out\BenchMSSQL.clw" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content (Join-Path $out 'BenchMSSQL.cwproj') -Encoding UTF8

$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" (Join-Path $out 'BenchMSSQL.cwproj') /p:Configuration=Release /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion' }
foreach ($dll in 'ClaRUN.dll', 'ClaASC.dll', 'ClaMSS.dll') { Copy-Item (Join-Path $ClarionRoot "bin\$dll") $out -Force }
Write-Host "Compilado: $out\BenchMSSQL.exe" -ForegroundColor Green

if ($Servidor) {
    @"
[Conexion]
Odbc=Driver={$DriverOdbc};Server=$Servidor;Database=$Base;Uid=$Usuario;Pwd=$Clave;Encrypt=no
Clarion=$Servidor,$Base,$Usuario,$Clave
[Bench]
Corridas=$Corridas
Detalle=$([int][bool]$Detalle)
"@ | Set-Content (Join-Path $out 'bench.ini') -Encoding Default
}
if ($Run) {
    Remove-Item (Join-Path $out 'resultados.txt') -ErrorAction SilentlyContinue
    $p = Start-Process (Join-Path $out 'BenchMSSQL.exe') -WorkingDirectory $out -PassThru
    if (-not $p.WaitForExit(1800000)) { $p.Kill(); throw 'La prueba no termino en 30 minutos (posible dialogo del driver)' }
    Get-Content (Join-Path $out 'resultados.txt') -Encoding Default
}
