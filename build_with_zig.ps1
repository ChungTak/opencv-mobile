#Requires -Version 5.1

<#
.SYNOPSIS
  使用 Zig 和 CMake 在 Windows 上交叉编译 OpenCV-Mobile。
.DESCRIPTION
  此脚本配置并构建 OpenCV-Mobile 库，使用 Zig 作为 C/C++ 编译器
  以支持跨目标架构编译，并使用 CMake 作为构建系统生成器。
.PARAMETER Target
  指定要构建的目标架构。默认为 'x86_64-linux-gnu'。
  有关支持的目标，请参阅帮助信息或 Zig 文档。
.PARAMETER Help
  显示帮助信息并退出。
.EXAMPLE
  .\build_opencv.ps1 -Target x86_64-windows-gnu
  为 x86_64 Windows (MinGW) 构建 OpenCV。
.EXAMPLE
  .\build_opencv.ps1 -Target aarch64-linux-android
  为 ARM64 Android 构建 OpenCV。
.EXAMPLE
  .\build_opencv.ps1 -Help
  显示用法和示例。
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$Target = 'x86_64-linux-gnu',

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# --- 帮助信息 ---
if ($Help) {
    Write-Host "用法: .\build_opencv.ps1 [选项]"
    Write-Host "选项:"
    Write-Host "  -Target <目标>     指定目标架构 (默认: x86_64-linux-gnu)"
    Write-Host "  -Help              显示此帮助信息"
    Write-Host ""
    Write-Host "支持的目标架构示例:"
    Write-Host "  x86_64-linux-gnu       - x86_64 Linux (GNU libc)"
    Write-Host "  aarch64-linux-gnu      - ARM64 Linux (GNU libc)"
    Write-Host "  aarch64-linux-android  - ARM64 Android"
    Write-Host "  arm-linux-android        - ARM 32-bit Android"
    Write-Host "  x86_64-windows-gnu   - x86_64 Windows (MinGW)"
    Write-Host "  x86_64-macos           - x86_64 macOS"
    Write-Host "  aarch64-macos          - ARM64 macOS"
    Write-Host "  riscv64-linux-gnu      - RISC-V 64-bit Linux"
    exit 0
}

# --- 参数配置 ---
# $PSScriptRoot 是脚本文件所在的目录，通常比 $PWD 更可靠
# 如果你不是从脚本文件运行，而是直接粘贴到终端，请使用 $ProjectRoot = $PWD.Path
$ProjectRoot = $PSScriptRoot # 或者 $ProjectRoot = (Get-Location).Path
$OpenCVSourceDir = Join-Path -Path $ProjectRoot -ChildPath "opencv-mobile"
$BuildType = "Release" # 或者 "Debug"
$InstallDir = Join-Path -Path $ProjectRoot -ChildPath "install_opencv_$Target"
$OpenCVBuildDir = Join-Path -Path $ProjectRoot -ChildPath "build_opencv_$Target"
$CMakeOptionsFile = Join-Path -Path $OpenCVSourceDir -ChildPath "options.txt"

# --- 依赖检查 ---

# 检查 Zig 是否安装
Write-Host "检查 Zig..." -ForegroundColor Cyan
$zigPath = Get-Command zig -ErrorAction SilentlyContinue
if (-not $zigPath) {
    Write-Host "错误: 未找到 Zig。请安装 Zig 并确保它在 PATH 环境变量中: https://ziglang.org/download/" -ForegroundColor Red
    exit 1
}
Write-Host "Zig 已找到: $($zigPath.Source)" -ForegroundColor Green

# 检查 CMake 是否安装
Write-Host "检查 CMake..." -ForegroundColor Cyan
$cmakePath = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmakePath) {
    Write-Host "错误: 未找到 CMake。请安装 CMake 并确保它在 PATH 环境变量中: https://cmake.org/download/" -ForegroundColor Red
    exit 1
}
Write-Host "CMake 已找到: $($cmakePath.Source)" -ForegroundColor Green

# 检查源代码是否存在
Write-Host "检查 OpenCV 源码目录..." -ForegroundColor Cyan
if (-not (Test-Path -Path $OpenCVSourceDir -PathType Container)) {
    Write-Host "错误: OpenCV 源码目录不存在: $OpenCVSourceDir" -ForegroundColor Red
    Write-Host "请确保已经通过 git 子模块克隆了 OpenCV-Mobile 代码 ('git submodule update --init --recursive')" -ForegroundColor Yellow
    exit 1
}
Write-Host "OpenCV 源码目录已找到。" -ForegroundColor Green

# 检查并读取 CMake 选项文件
Write-Host "检查 CMake 选项文件..." -ForegroundColor Cyan
if (-not (Test-Path -Path $CMakeOptionsFile -PathType Leaf)) {
    Write-Host "错误: OpenCV cmake 选项文件不存在: $CMakeOptionsFile" -ForegroundColor Red
    exit 1
}

# 从文件读取 CMake 选项 (忽略空行和注释行)
$CmakeOptionsFromFile = Get-Content -Path $CMakeOptionsFile | Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' }
Write-Host "已读取 $($CmakeOptionsFromFile.Count) 个 CMake 选项。" -ForegroundColor Green


# --- 构建准备 ---

# 创建 OpenCV 构建目录 (如果不存在)
Write-Host "创建构建目录: $OpenCVBuildDir" -ForegroundColor Cyan
if (-not (Test-Path -Path $OpenCVBuildDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OpenCVBuildDir -Force | Out-Null
}

# 进入构建目录
Push-Location $OpenCVBuildDir

# --- 配置 CMake ---

# 设置 Zig 编译器环境变量 (仅对此脚本及其子进程有效)
# 注意: 在 PowerShell 中，直接设置 $env:VAR 即可
$env:CC = "zig cc -target $Target"
$env:CXX = "zig c++ -target $Target"

# 构建 CMake 命令参数列表
$cmakeArgs = @(
    "-DCMAKE_INSTALL_PREFIX=$InstallDir",
    "-DCMAKE_BUILD_TYPE=$BuildType"
)

# 添加从文件读取的选项
$cmakeArgs += $CmakeOptionsFromFile

# 添加显式禁用的选项 (如果需要)
$cmakeArgs += "-DBUILD_opencv_world=OFF"

# 添加源码目录路径作为最后一个参数
$cmakeArgs += $OpenCVSourceDir

# 打印配置信息
Write-Host "OpenCV-Mobile 构建配置:" -ForegroundColor Blue
Write-Host "  源码目录: $OpenCVSourceDir" -ForegroundColor Blue
Write-Host "  构建类型: $BuildType" -ForegroundColor Blue
Write-Host "  安装目录: $InstallDir" -ForegroundColor Blue
Write-Host "  目标架构: $Target" -ForegroundColor Blue
Write-Host "  CC: $($env:CC)" -ForegroundColor Blue
Write-Host "  CXX: $($env:CXX)" -ForegroundColor Blue

# 执行 CMake 配置
Write-Host "执行 CMake 配置..." -ForegroundColor Green
Write-Host "命令: cmake $cmakeArgs" -ForegroundColor Gray # 显示将要执行的命令
cmake $cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake 配置失败!" -ForegroundColor Red
    Pop-Location # 确保返回原始目录
    exit 1
}
Write-Host "CMake 配置成功。" -ForegroundColor Green

# --- 编译 ---
# 使用 cmake --build 而不是直接调用 make/ninja/msbuild，更具可移植性
# --parallel 会让 CMake 自动使用所有可用的核心进行并行编译
Write-Host "开始编译 OpenCV (使用 cmake --build)..." -ForegroundColor Green
cmake --build . --config $BuildType --parallel
if ($LASTEXITCODE -ne 0) {
    Write-Host "OpenCV 编译失败!" -ForegroundColor Red
    Pop-Location # 确保返回原始目录
    exit 1
}
Write-Host "编译成功。" -ForegroundColor Green

# --- 安装 ---
# 使用 cmake --install 进行安装
Write-Host "开始安装 OpenCV (使用 cmake --install)..." -ForegroundColor Green
cmake --install . --config $BuildType
if ($LASTEXITCODE -ne 0) {
    Write-Host "安装 OpenCV 失败!" -ForegroundColor Red
    Pop-Location # 确保返回原始目录
    exit 1
}

# --- 完成 ---
Write-Host "安装成功!" -ForegroundColor Green
Write-Host "OpenCV 库文件位于: $(Join-Path $InstallDir 'lib')" -ForegroundColor Green
Write-Host "OpenCV 头文件位于: $(Join-Path $InstallDir 'include' 'opencv4')" -ForegroundColor Green

# 返回到项目根目录
Pop-Location
Write-Host "构建过程完成。" -ForegroundColor Green
exit 0
