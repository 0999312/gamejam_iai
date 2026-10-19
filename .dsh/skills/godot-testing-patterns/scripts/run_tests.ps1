# 可运行的 headless 测试脚本（CI / 本地一键跑）。
# 用法：
#   pwsh -File tests\..\run_tests.ps1                        # 全部
#   pwsh -File run_tests.ps1 -Select damage                  # 文件名包含 damage
#   pwsh -File run_tests.ps1 -UnitTestName parry             # 测试名包含 parry
# 退出码 = GUT 退出码（0 全过 / 1 有失败），可直接作为 CI 门控。

param(
    [string]$GodotExe = "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe",
    [string]$ProjectPath = ".",
    [string]$TestDir = "res://tests",
    [string]$Select = "",
    [string]$UnitTestName = "",
    [string]$JUnitXml = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot 可执行文件不存在: $GodotExe"
    exit 2
}

$gutArgs = @(
    "--headless",
    "--path", $ProjectPath,
    "-s", "addons/gut/gut_cmdln.gd",
    "-gdir=$TestDir",
    "-ginclude_subdirs",
    "-gexit"
)

if ($Select -ne "") { $gutArgs += "-gselect=$Select" }
if ($UnitTestName -ne "") { $gutArgs += "-gunit_test_name=$UnitTestName" }
if ($JUnitXml -ne "") { $gutArgs += "-gjunit_xml_file=$JUnitXml" }

Write-Host "> $GodotExe $($gutArgs -join ' ')" -ForegroundColor DarkGray
& $GodotExe @gutArgs
$code = $LASTEXITCODE

if ($code -eq 0) {
    Write-Host "GUT: all tests passed" -ForegroundColor Green
} else {
    Write-Host "GUT: failures detected (exit $code)" -ForegroundColor Red
}
exit $code
