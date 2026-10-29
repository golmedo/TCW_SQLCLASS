# Compila tests\TestMsSQL.clw con Clarion 11 en tests\.build y (si se pasa -Conexion) lo ejecuta.
#   .\build-test.ps1
#   .\build-test.ps1 -Conexion 'Server=PC\INSTANCIA;Database=base;User=u;Password=p'
# Usa la SQLClass6 extendida de ..\tcwDriverMariaDB\sqlclass6 (ExecEx, ExecSP, LogFile) sin StringTheory.
param([string]$Conexion = '', [string]$ClarionRoot = 'C:\clarion11Col')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out  = Join-Path $root 'tests\.build'
$enc  = [Text.Encoding]::GetEncoding(1252)
New-Item -ItemType Directory $out -Force | Out-Null

# fuentes en cp1252 y CRLF (el compilador de Clarion no acepta LF solo)
$fuentes = @(Get-ChildItem (Join-Path $root 'clarion') -File) + @(Get-Item (Join-Path $root 'tests\TestMsSQL.clw')) +
           @(Get-ChildItem (Join-Path $root '..\tcwDriverMariaDB\sqlclass6') -File)
foreach ($f in $fuentes) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    try { $t = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $t = $enc.GetString($bytes) }   # UTF-8 valido o cp1252 (IDE)
    $t = $t.TrimStart([char]0xFEFF) -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText((Join-Path $out $f.Name), $t, $enc)
}

@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{6B2E8F14-9A3C-4D57-8E61-0F4C7A2B9D58}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>Exe</OutputType>
    <AssemblyName>TestMsSQL</AssemblyName>
    <OutputName>TestMsSQL</OutputName>
    <Model>Dll</Model>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bSQLClass6SinStringTheory=&gt;1</DefineConstants>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
    <FileDriver Include="ASCII" />
    <Compile Include="$out\TestMsSQL.clw" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content (Join-Path $out 'TestMsSQL.cwproj') -Encoding UTF8

$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" (Join-Path $out 'TestMsSQL.cwproj') /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaASC.dll') $out -Force
Write-Host "Compilado: $out\TestMsSQL.exe" -ForegroundColor Green

if ($Conexion) {
    Remove-Item (Join-Path $out 'resultados.txt') -ErrorAction SilentlyContinue
    $p = Start-Process (Join-Path $out 'TestMsSQL.exe') -ArgumentList "`"$Conexion`"" -WorkingDirectory $out -PassThru
    if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'La prueba no termino en 2 minutos' }
    Get-Content (Join-Path $out 'resultados.txt') -Encoding Default
}
