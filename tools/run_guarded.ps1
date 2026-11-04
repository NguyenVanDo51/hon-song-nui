# Run Godot with a memory + time watchdog (a runaway draw loop once ate 60 GB and froze the machine).
# usage: powershell -File tools/run_guarded.ps1 -Log out.txt -MaxMB 1500 -MaxSec 120 -GArgs "--headless --path . -s sim/tests.gd"
# Watches every Godot process started by this run (the console exe launches the real one) and kills them all
# when their private memory goes over MaxMB or the run exceeds MaxSec.
param(
	[string]$Log = "$env:TEMP\hsn_run.log",
	[int]$MaxMB = 1500,
	[int]$MaxSec = 120,
	[string]$GArgs = ""
)
$exe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$t0 = Get-Date
$p = Start-Process -FilePath $exe -ArgumentList $GArgs -WorkingDirectory (Split-Path $PSScriptRoot -Parent) `
	-RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru -WindowStyle Hidden
$peak = 0; $why = "exit"
function Mine { Get-Process -Name "Godot_v4.7.2-stable_win64*" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -ge $t0.AddSeconds(-1) } }
while (-not $p.HasExited) {
	Start-Sleep -Milliseconds 400
	$mb = 0
	foreach ($q in Mine) { $mb += [int]($q.PrivateMemorySize64 / 1MB) }
	if ($mb -gt $peak) { $peak = $mb }
	if ($mb -gt $MaxMB) { $why = "KILLED: memory $mb MB > $MaxMB" }
	elseif (((Get-Date) - $t0).TotalSeconds -gt $MaxSec) { $why = "KILLED: time > $MaxSec s" }
	if ($why -ne "exit") {
		foreach ($q in Mine) { Stop-Process -Id $q.Id -Force -ErrorAction SilentlyContinue }
		break
	}
}
$line = "[guard] $why, peak $peak MB, $([int]((Get-Date) - $t0).TotalSeconds) s"
Set-Content -Path "$Log.guard" -Value $line -Encoding utf8
$line
