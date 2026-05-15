# 卸载 VS2022 Visual Assist 插件

$ErrorActionPreference = "Stop"

# 1. 查找 VS2022 VSIXInstaller
$vsixPaths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\VSIXInstaller.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\VSIXInstaller.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\VSIXInstaller.exe"
)

$vsixInstaller = $null
foreach ($p in $vsixPaths) {
    if (Test-Path $p) {
        $vsixInstaller = $p
        break
    }
}

if (-not $vsixInstaller) {
    Write-Error "未找到 VS2022 的 VSIXInstaller.exe"
    exit 1
}

Write-Host "找到 VSIXInstaller: $vsixInstaller" -ForegroundColor Green

# 2. VA 扩展 ID
$vaId = "44630d46-96b5-488c-8df926e21db8c1a3"

# 3. 尝试使用 VSIXInstaller 卸载
Write-Host "正在卸载 Visual Assist (ID: $vaId)..." -ForegroundColor Yellow
& $vsixInstaller /uninstall:$vaId

if ($LASTEXITCODE -eq 0) {
    Write-Host "Visual Assist 卸载成功" -ForegroundColor Green
} else {
    Write-Warning "VSIXInstaller 退出码: $LASTEXITCODE，尝试直接清理..."
    
    # 4. 兜底：直接删除扩展目录
    $vsDir = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Filter "17.0_*" | Select-Object -First 1
    if ($vsDir) {
        $extDir = Join-Path $vsDir.FullName "Extensions"
        $vaDirs = Get-ChildItem -Path $extDir -Recurse -Filter "VA_X64.dll" -ErrorAction SilentlyContinue
        foreach ($vaDll in $vaDirs) {
            $vaExtDir = $vaDll.Directory.Parent.FullName
            Write-Host "删除扩展目录: $vaExtDir" -ForegroundColor Yellow
            Remove-Item -Recurse -Force $vaExtDir
        }
    }
    
    # 5. 更新 VS 配置
    $devenv = Join-Path (Split-Path $vsixInstaller) "devenv.exe"
    if (Test-Path $devenv) {
        Write-Host "更新 Visual Studio 配置..." -ForegroundColor Yellow
        & $devenv /updateconfiguration
    }
    
    Write-Host "清理完成" -ForegroundColor Green
}
