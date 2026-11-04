# Export the web build to build/web and zip it for upload (itch.io: "HTML" project, upload the zip; GitHub Pages: push build/web).
# usage: powershell -File tools/export_web.ps1
# Needs the 4.7.2 export templates in %APPDATA%\Godot\export_templates\4.7.2.stable (web_nothreads_*.zip).
$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root "build\web"
if (Test-Path $web) { Remove-Item -Recurse -Force $web }
New-Item -ItemType Directory -Force $web | Out-Null
& powershell -NoProfile -File (Join-Path $PSScriptRoot "run_guarded.ps1") -Log "$env:TEMP\hsn_export.log" -MaxMB 3000 -MaxSec 300 `
	-GArgs "--headless --path . --export-release Web build/web/index.html"
if (-not (Test-Path (Join-Path $web "index.pck"))) { Write-Error "export failed, see $env:TEMP\hsn_export.log"; exit 1 }
$zip = Join-Path $root "build\hon-song-nui-web.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $web "*") -DestinationPath $zip
Get-ChildItem $web | Select-Object Name, @{n='KB';e={[int]($_.Length/1KB)}} | Format-Table | Out-String
"zip: $zip ($([int]((Get-Item $zip).Length/1MB)) MB)"
