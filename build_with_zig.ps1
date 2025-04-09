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
$ProjectRoot = $PSScriptRoot # 或者 $ProjectRoot = (Get-Location).Path
$OpenCVSourceDir = Join-Path -Path $ProjectRoot -ChildPath "opencv-mobile"
$BuildType = "Release" # 或者 "Debug"
$InstallDir = Join-Path -Path $ProjectRoot -ChildPath "install_opencv_$Target"
$OpenCVBuildDir = Join-Path -Path $ProjectRoot -ChildPath "build_opencv_$Target"
$CMakeOptionsFile = Join-Path -Path $OpenCVSourceDir -ChildPath "options.txt"

# --- 依赖检查 ---
Write-Host "检查 Zig..." -ForegroundColor Cyan
$zigPath = Get-Command zig -ErrorAction SilentlyContinue
if (-not $zigPath) {
    Write-Host "错误: 未找到 Zig。请安装 Zig 并确保它在 PATH 环境变量中: https://ziglang.org/download/" -ForegroundColor Red
    exit 1
}
Write-Host "Zig 已找到: $($zigPath.Source)" -ForegroundColor Green

Write-Host "检查 CMake..." -ForegroundColor Cyan
$cmakePath = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmakePath) {
    Write-Host "错误: 未找到 CMake。请安装 CMake 并确保它在 PATH 环境变量中: https://cmake.org/download/" -ForegroundColor Red
    exit 1
}
Write-Host "CMake 已找到: $($cmakePath.Source)" -ForegroundColor Green

Write-Host "检查 OpenCV 源码目录..." -ForegroundColor Cyan
if (-not (Test-Path -Path $OpenCVSourceDir -PathType Container)) {
    Write-Host "错误: OpenCV 源码目录不存在: $OpenCVSourceDir" -ForegroundColor Red
    Write-Host "请确保已经通过 git 子模块克隆了 OpenCV-Mobile 代码 ('git submodule update --init --recursive')" -ForegroundColor Yellow
    exit 1
}
Write-Host "OpenCV 源码目录已找到。" -ForegroundColor Green

Write-Host "检查 CMake 选项文件..." -ForegroundColor Cyan
if (-not (Test-Path -Path $CMakeOptionsFile -PathType Leaf)) {
    Write-Host "错误: OpenCV cmake 选项文件不存在: $CMakeOptionsFile" -ForegroundColor Red
    exit 1
}

$CmakeOptionsFromFile = Get-Content -Path $CMakeOptionsFile | Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' }
Write-Host "已读取 $($CmakeOptionsFromFile.Count) 个 CMake 选项。" -ForegroundColor Green

# --- 构建准备 ---
Write-Host "创建构建目录: $OpenCVBuildDir" -ForegroundColor Cyan
if (-not (Test-Path -Path $OpenCVBuildDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OpenCVBuildDir -Force | Out-Null
}

# 进入构建目录 (使用 try/finally 确保 Pop-Location 总能执行)
Push-Location $OpenCVBuildDir
try {
    # --- 配置 CMake ---
    $env:CC = "zig cc -target $Target"
    $env:CXX = "zig c++ -target $Target"

    $cmakeArgs = @(
        "-DCMAKE_INSTALL_PREFIX=$InstallDir",
        "-DCMAKE_BUILD_TYPE=$BuildType"
    )
    $cmakeArgs += $CmakeOptionsFromFile
    $cmakeArgs += "-DBUILD_opencv_world=OFF"
    $cmakeArgs += $OpenCVSourceDir # 源码目录应是最后一个参数

    Write-Host "OpenCV-Mobile 构建配置:" -ForegroundColor Blue
    Write-Host "  源码目录: $OpenCVSourceDir" -ForegroundColor Blue
    Write-Host "  构建类型: $BuildType" -ForegroundColor Blue
    Write-Host "  安装目录: $InstallDir" -ForegroundColor Blue
    Write-Host "  目标架构: $Target" -ForegroundColor Blue
    Write-Host "  CC: $($env:CC)" -ForegroundColor Blue
    Write-Host "  CXX: $($env:CXX)" -ForegroundColor Blue

    Write-Host "执行 CMake 配置..." -ForegroundColor Green
    Write-Host "命令: cmake $($cmakeArgs -join ' ')" -ForegroundColor Gray # 更清晰地显示命令
    & cmake $cmakeArgs # 使用 & 调用操作符
    if ($LASTEXITCODE -ne 0) {
        Write-Host "CMake 配置失败! (退出码: $LASTEXITCODE)" -ForegroundColor Red
        exit 1 # 直接退出，因为后续步骤无法进行
    }
    Write-Host "CMake 配置成功。" -ForegroundColor Green

    # --- 编译 ---
    Write-Host "开始编译 OpenCV (使用 cmake --build)..." -ForegroundColor Green
    & cmake --build . --config $BuildType --parallel
    if ($LASTEXITCODE -ne 0) {
        Write-Host "OpenCV 编译失败! (退出码: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "编译成功。" -ForegroundColor Green

    # --- 安装 ---
    Write-Host "开始安装 OpenCV (使用 cmake --install)..." -ForegroundColor Green
    & cmake --install . --config $BuildType
    if ($LASTEXITCODE -ne 0) {
        Write-Host "安装 OpenCV 失败! (退出码: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "CMake install 命令执行完毕。" -ForegroundColor Green # 注意：这只表示命令执行完成，不代表安装内容一定正确

    # --- 检查安装结果 ---
    $expectedLibDir = Join-Path $InstallDir 'lib'
    # !! 修正 Join-Path 错误 !!
    $expectedIncludeDir = Join-Path $InstallDir 'include\opencv4' # 将 include 和 opencv4 合并为子路径

    Write-Host "检查安装目录内容..." -ForegroundColor Cyan
    if ((Test-Path -Path $InstallDir -PathType Container) `
        -and (Test-Path -Path $expectedLibDir -PathType Container) `
        -and (Test-Path -Path $expectedIncludeDir -PathType Container)) {

        Write-Host "安装成功!" -ForegroundColor Green
        Write-Host "OpenCV 库文件位于: $expectedLibDir" -ForegroundColor Green
        Write-Host "OpenCV 头文件位于: $expectedIncludeDir" -ForegroundColor Green
        Write-Host "构建过程完成。" -ForegroundColor Green
        exit 0 # 明确成功退出
    } else {
        Write-Host "安装检查失败! 预期目录未完全找到:" -ForegroundColor Red
        Write-Host "  检查 $InstallDir : $(Test-Path -Path $InstallDir -PathType Container)" -ForegroundColor Yellow
        Write-Host "  检查 $expectedLibDir : $(Test-Path -Path $expectedLibDir -PathType Container)" -ForegroundColor Yellow
        Write-Host "  检查 $expectedIncludeDir : $(Test-Path -Path $expectedIncludeDir -PathType Container)" -ForegroundColor Yellow
        exit 1 # 安装不完整，报告错误
    }

} finally {
    # 确保无论成功还是失败，都返回到原始目录
    Pop-Location
}