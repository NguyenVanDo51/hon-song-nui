# Smoke-test the exported web build: serve build/web on localhost, open it in headless Edge (software WebGL),
# wait real seconds, save a screenshot. Pass a query to drive the debug flags, e.g. -Query "?screen=campaign".
# usage: powershell -File tools/web_smoke.ps1 -Out shots/web.png -Wait 25 [-Query "..."]
param([string]$Out = "shots\web.png", [int]$Wait = 25, [string]$Query = "")
$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root "build\web"
$port = 8765
$srv = Start-Process python -ArgumentList @("-m", "http.server", "$port", "--bind", "127.0.0.1") -WorkingDirectory $web -WindowStyle Hidden -PassThru
Start-Sleep 2
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
$outAbs = Join-Path $root $Out
$prof = Join-Path $env:TEMP "hsn_edge_profile"
$p = Start-Process $edge -PassThru -WindowStyle Hidden -RedirectStandardError "$env:TEMP\hsn_edge_console.log" -ArgumentList @("--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--enable-logging=stderr", "--v=0",
	"--window-size=1600,900", "--timeout=$($Wait * 1000)", "--screenshot=$outAbs", "--user-data-dir=$prof", "--no-first-run",
	"http://127.0.0.1:$port/index.html$Query")
if (-not $p.WaitForExit(($Wait + 60) * 1000)) { Stop-Process -Id $p.Id -Force; "edge timed out" }
Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue
if (Test-Path $outAbs) { "screenshot: $outAbs" } else { "no screenshot" }
