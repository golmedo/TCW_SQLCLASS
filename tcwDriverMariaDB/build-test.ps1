# Compila tests\TestMaria.clw con Clarion 11 en tests\.build y (si se pasa -Conexion) lo ejecuta.
#   .\build-test.ps1
#   .\build-test.ps1 -Conexion 'Server=127.0.0.1;Port=3306;Database=test;User=u;Password=p'
param([string]$Conexion = '', [string]$ClarionRoot = 'C:\clarion11Col')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out  = Join-Path $root 'tests\.build'
$enc  = [Text.Encoding]::GetEncoding(1252)
New-Item -ItemType Directory $out -Force | Out-Null

# fuentes en cp1252 y CRLF (el compilador de Clarion no acepta LF solo)
foreach ($f in @(Get-ChildItem (Join-Path $root 'clarion') -File) + @(Get-Item (Join-Path $root 'tests\TestMaria.clw'))) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    try { $t = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $t = $enc.GetString($bytes) }   # UTF-8 valido o cp1252 (IDE)
    $t = $t.TrimStart([char]0xFEFF) -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText((Join-Path $out $f.Name), $t, $enc)
}
Copy-Item (Join-Path $root 'lib\libmariadb.lib'), (Join-Path $root 'bin\libmariadb.dll') $out -Force

@"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{8E1B5C2D-4F7A-4B9E-A3C1-6D2F0E9B7A15}</ProjectGuid>
    <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '`$(Platform)' == '' ">Win32</Platform>
    <OutputType>Exe</OutputType>
    <AssemblyName>TestMaria</AssemblyName>
    <OutputName>TestMaria</OutputName>
    <Model>Dll</Model>
    <DefineConstants>_ABCDllMode_=&gt;0%3b_ABCLinkMode_=&gt;1%3bStringTheoryLinkMode=&gt;1%3bStringTheoryDLLMode=&gt;0</DefineConstants>
  </PropertyGroup>
  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <DebugSymbols>True</DebugSymbols><DebugType>Full</DebugType><vid>full</vid>
  </PropertyGroup>
  <ItemGroup>
    <FileDriver Include="ASCII" />
    <Compile Include="$out\TestMaria.clw" />
    <Library Include="libmariadb.lib" />
  </ItemGroup>
  <Import Project="`$(ClarionBinPath)\SoftVelocity.Build.Clarion.targets" />
</Project>
"@ | Set-Content (Join-Path $out 'TestMaria.cwproj') -Encoding UTF8

$env:ClarionBinPath = Join-Path $ClarionRoot 'bin'
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" (Join-Path $out 'TestMaria.cwproj') /p:Configuration=Debug /p:Platform=Win32 /nologo /v:minimal
if ($LASTEXITCODE) { throw 'Fallo la compilacion' }
Copy-Item (Join-Path $ClarionRoot 'bin\ClaRUN.dll'), (Join-Path $ClarionRoot 'bin\ClaASC.dll') $out -Force
Write-Host "Compilado: $out\TestMaria.exe" -ForegroundColor Green

if ($Conexion) {
    Remove-Item (Join-Path $out 'resultados.txt') -ErrorAction SilentlyContinue
    $p = Start-Process (Join-Path $out 'TestMaria.exe') -ArgumentList "`"$Conexion`"" -WorkingDirectory $out -PassThru
    if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'La prueba no termino en 2 minutos' }
    Get-Content (Join-Path $out 'resultados.txt') -Encoding Default
}
