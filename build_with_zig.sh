#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色
# 解析命令行参数
for arg in "$@"; do
  case $arg in
    --target=*)
      TARGET="${arg#*=}"
      shift
      ;;
    --help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --target=<目标>    指定目标架构 (默认: x86_64-linux-gnu)"
      echo "  --help             显示此帮助信息"
      echo ""
      echo "支持的目标架构示例:"
      echo "  x86_64-linux-gnu      - x86_64 Linux (GNU libc)"
      echo "  aarch64-linux-gnu     - ARM64 Linux (GNU libc)"
      echo "  aarch64-linux-android     - ARM64 Android"
      echo "  arm-linux-android         - ARM 32-bit Android"      
      echo "  x86_64-windows-gnu    - x86_64 Windows (MinGW)"
      echo "  x86_64-macos          - x86_64 macOS"
      echo "  aarch64-macos         - ARM64 macOS"
      echo "  riscv64-linux-gnu      - RISC-V 64-bit Linux"
      exit 0
      ;;
  esac
done
# 参数配置
PROJECT_ROOT_DIR="$(pwd)"
OPENCV_SRC_DIR="$PROJECT_ROOT_DIR/opencv-mobile"
BUILD_TYPE="Release"
INSTALL_DIR="$PROJECT_ROOT_DIR/install_opencv_${TARGET}"


# 检查Zig是否安装
if ! command -v zig &> /dev/null; then
    echo "错误: 未找到Zig。请安装Zig: https://ziglang.org/download/"
    exit 1
fi

# 检查CMake是否安装
if ! command -v cmake &> /dev/null; then
    echo "错误: 未找到CMake。请安装CMake: https://cmake.org/download/"
    exit 1
fi

# 检查源代码是否存在
if [ ! -d "$OPENCV_SRC_DIR" ]; then
    echo -e "${RED}错误: OpenCV源码目录不存在: $OPENCV_SRC_DIR${NC}"
    echo -e "${YELLOW}请确保已经通过git子模块克隆了OpenCV-Mobile代码${NC}"
    exit 1
fi

# 读取cmake选项
CMAKE_OPTIONS_FILE="$OPENCV_SRC_DIR/options.txt"
if [ ! -f "$CMAKE_OPTIONS_FILE" ]; then
    echo -e "${RED}错误: OpenCV cmake选项文件不存在: $CMAKE_OPTIONS_FILE${NC}"
    exit 1
fi

# 创建OpenCV构建目录
OPENCV_BUILD_DIR="$PROJECT_ROOT_DIR/build_opencv_${TARGET}"
mkdir -p "$OPENCV_BUILD_DIR"

# 进入构建目录
cd "$OPENCV_BUILD_DIR"

# 读取cmake选项到数组
CMAKE_OPTIONS=()
while read -r line; do
    if [[ ! -z "$line" && ! "$line" =~ ^# ]]; then
        CMAKE_OPTIONS+=("$line")
    fi
done < "$OPENCV_SRC_DIR/options.txt"

# 构建CMake命令
export CC="zig cc -target $TARGET"
export CXX="zig c++ -target $TARGET"
CMAKE_CMD="cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
CMAKE_CMD="$CMAKE_CMD -DCMAKE_BUILD_TYPE=$BUILD_TYPE"

# 添加额外选项
for option in "${CMAKE_OPTIONS[@]}"; do
    CMAKE_CMD="$CMAKE_CMD $option"
done
# 显式禁用所有可能引起问题的组件
CMAKE_CMD="$CMAKE_CMD -DBUILD_opencv_world=OFF $OPENCV_SRC_DIR"

# 打印配置信息
echo -e "${BLUE}OpenCV-Mobile 构建配置:${NC}"
echo -e "${BLUE}  源码目录: $OPENCV_SRC_DIR${NC}"
echo -e "${BLUE}  构建类型: $BUILD_TYPE${NC}"
echo -e "${BLUE}  安装目录: $INSTALL_DIR${NC}"

# 执行CMake配置
echo -e "${GREEN}执行: $CMAKE_CMD${NC}"
eval "$CMAKE_CMD"

# 编译
echo -e "${GREEN}开始编译OpenCV...${NC}"
make -j$(nproc)

# 安装
echo -e "开始安装...${NC}"
make install

# 检查安装结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}安装成功!${NC}"
    echo -e "${GREEN}OpenCV库文件位于: $INSTALL_DIR/lib/${NC}"
    echo -e "${GREEN}OpenCV头文件位于: $INSTALL_DIR/include/opencv4/${NC}"
    
    # 返回到项目根目录
    cd $PROJECT_ROOT_DIR
else
    echo -e "${RED}安装OpenCV失败!${NC}"
    exit 1
fi
