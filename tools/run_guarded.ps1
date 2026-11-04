# Run Godot with a memory + time watchdog (a runaway draw loop once ate 60 GB and froze the machine).
# usage: powershell -File tools/run_guarded.ps1 -Log out.txt -MaxMB 1500 -MaxSec 120 -GArgs "--headless --path . -s sim/tests.gd"
param(
	[string]$Log = "$env:TEMP\hsn_run.log",
	[int]$MaxMB = 1500,
	[int]$MaxSec = 120,
	[string]$GArgs = ""
)
$exe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$p = Start-Process -FilePath $exe -ArgumentList $GArgs -WorkingDirectory (Split-Path $PSScriptRoot -Parent) `
	-RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru -WindowStyle Hidden
$peak = 0; $t0 = Get-Date; $why = "exit"
while (-not $p.HasExited) {
	Start-Sleep -Milliseconds 500
	$kids = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" -ErrorAction SilentlyContinue
	$mb = 0
	foreach ($id in @($p.Id) + @($kids | ForEach-Object { $_.ProcessId })) {
		$q = Get-Process -Id $id -ErrorAction SilentlyContinue
		if ($q) { $mb += [int]($q.PrivateMemorySize64 / 1MB) }
	}
	if ($mb -gt $peak) { $peak = $mb }
	$why = $null
	if ($mb -gt $MaxMB) { $why = "KILLED: memory $mb MB > $MaxMB" }
	elseif (((Get-Date) - $t0).TotalSeconds -gt $MaxSec) { $why = "KILLED: time > $MaxSec s" }
	if ($why) {
		foreach ($k in $kids) { Stop-Process -Id $k.ProcessId -Force -ErrorAction SilentlyContinue }
		Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
		break
	}
	$why = "exit"
}
"[guard] $why, peak $peak MB, $([int]((Get-Date) - $t0).TotalSeconds) s" | Tee-Object -Variable line | Out-Null; Add-Content -Path $Log -Value $line -Encoding utf8; $line
