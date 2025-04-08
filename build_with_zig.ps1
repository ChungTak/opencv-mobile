<#
.SYNOPSIS
构建OpenCV-Mobile的PowerShell脚本

.DESCRIPTION
这个脚本用于跨平台构建OpenCV-Mobile库

.PARAMETER Target
指定目标架构 (默认: x86_64-linux-gnu)

.PARAMETER Help
显示帮助信息

.EXAMPLE
.\build-opencv.ps1 -Target "x86_64-windows-gnu"
#>

param(
    [string]$Target = "x86_64-linux-gnu",
    [switch]$Help
)

# 设置颜色
$Host.UI.RawUI.ForegroundColor = "White"
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# 显示帮助信息
if ($Help) {
    Write-Host "用法: $($MyInvocation.MyCommand.Name) [选项]"
    Write-Host "选项:"
    Write-Host "  -Target <目标>    指定目标架构 (默认: x86_64-linux-gnu)"
    Write-Host "  -Help             显示此帮助信息"
    Write-Host ""
    Write-Host "支持的目标架构示例:"
    Write-Host "  x86_64-linux-gnu      - x86_64 Linux (GNU libc)"
    Write-Host "  aarch64-linux-gnu     - ARM64 Linux (GNU libc)"
    Write-Host "  aarch64-linux-android - ARM64 Android"
    Write-Host "  arm-linux-android     - ARM 32-bit Android"      
    Write-Host "  x86_64-windows-gnu    - x86_64 Windows (MinGW)"
    Write-Host "  x86_64-macos          - x86_64 macOS"
    Write-Host "  aarch64-macos         - ARM64 macOS"
    Write-Host "  riscv64-linux-gnu     - RISC-V 64-bit Linux"
    exit 0
}

# 参数配置
$ProjectRootDir = Get-Location
$OpenCvSrcDir = Join-Path $ProjectRootDir "opencv-mobile"
$BuildType = "Release"
$InstallDir = Join-Path $ProjectRootDir "install_opencv_$Target"

# 检查Zig是否安装
if (-not (Get-Command zig -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor $Red "错误: 未找到Zig。请安装Zig: https://ziglang.org/download/"
    exit 1
}

# 检查CMake是否安装
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor $Red "错误: 未找到CMake。请安装CMake: https://cmake.org/download/"
    exit 1
}

# 检查源代码是否存在
if (-not (Test-Path $OpenCvSrcDir -PathType Container)) {
    Write-Host -ForegroundColor $Red "错误: OpenCV源码目录不存在: $OpenCvSrcDir"
    Write-Host -ForegroundColor $Yellow "请确保已经通过git子模块克隆了OpenCV-Mobile代码"
    exit 1
}

# 读取cmake选项
$CmakeOptionsFile = Join-Path $OpenCvSrcDir "options.txt"
if (-not (Test-Path $CmakeOptionsFile -PathType Leaf)) {
    Write-Host -ForegroundColor $Red "错误: OpenCV cmake选项文件不存在: $CmakeOptionsFile"
    exit 1
}

# 创建OpenCV构建目录
$OpenCvBuildDir = Join-Path $ProjectRootDir "build_opencv_$Target"
New-Item -ItemType Directory -Path $OpenCvBuildDir -Force | Out-Null

# 进入构建目录
Set-Location $OpenCvBuildDir

# 读取cmake选项
$CmakeOptions = @()
Get-Content $CmakeOptionsFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -ne "" -and -not $line.StartsWith("#")) {
        $CmakeOptions += $line
    }
}

# 设置环境变量
$env:CC = "zig cc -target $Target"
$env:CXX = "zig c++ -target $Target"

# 构建CMake命令
$CmakeCmd = "cmake -DCMAKE_INSTALL_PREFIX=$InstallDir"
$CmakeCmd += " -DCMAKE_BUILD_TYPE=$BuildType"

# 添加额外选项
foreach ($option in $CmakeOptions) {
    $CmakeCmd += " $option"
}

# 显式禁用所有可能引起问题的组件
$CmakeCmd += " -DBUILD_opencv_world=OFF $OpenCvSrcDir"

# 打印配置信息
Write-Host -ForegroundColor $Blue "OpenCV-Mobile 构建配置:"
Write-Host -ForegroundColor $Blue "  源码目录: $OpenCvSrcDir"
Write-Host -ForegroundColor $Blue "  构建类型: $BuildType"
Write-Host -ForegroundColor $Blue "  安装目录: $InstallDir"

# 执行CMake配置
Write-Host -ForegroundColor $Green "执行: $CmakeCmd"
Invoke-Expression $CmakeCmd

# 检查CMake配置是否成功
if ($LASTEXITCODE -ne 0) {
    Write-Host -ForegroundColor $Red "CMake配置失败!"
    exit $LASTEXITCODE
}

# 编译
Write-Host -ForegroundColor $Green "开始编译OpenCV..."
$cpuCores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
& cmake --build . --config $BuildType --parallel $cpuCores

# 检查编译是否成功
if ($LASTEXITCODE -ne 0) {
    Write-Host -ForegroundColor $Red "编译OpenCV失败!"
    exit $LASTEXITCODE
}

# 安装
Write-Host "开始安装..."
& cmake --install .

# 检查安装结果
if ($LASTEXITCODE -eq 0) {
    Write-Host -ForegroundColor $Green "安装成功!"
    Write-Host -ForegroundColor $Green "OpenCV库文件位于: $(Join-Path $InstallDir "lib")"
    Write-Host -ForegroundColor $Green "OpenCV头文件位于: $(Join-Path $InstallDir "include\opencv4")"
    
    # 返回到项目根目录
    Set-Location $ProjectRootDir
} else {
    Write-Host -ForegroundColor $Red "安装OpenCV失败!"
    exit 1
}
