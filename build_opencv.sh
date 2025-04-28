#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 参数配置
PROJECT_ROOT_DIR="$(pwd)"
OPENCV_SRC_DIR="$PROJECT_ROOT_DIR/third_party/opencv-mobile"
BUILD_TYPE="Release"
INSTALL_DIR="$PROJECT_ROOT_DIR/install_opencv"
CLEAN=0

# 解析命令行参数
for arg in "$@"; do
    case $arg in
        clean)
            CLEAN=1
            ;;
        debug)
            BUILD_TYPE="Debug"
            ;;
        *)
            echo -e "${YELLOW}未知参数: $arg${NC}"
            ;;
    esac
done

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
OPENCV_BUILD_DIR="$PROJECT_ROOT_DIR/build_opencv"
mkdir -p "$OPENCV_BUILD_DIR"

# 清理
if [ $CLEAN -eq 1 ]; then
    echo -e "${BLUE}清理OpenCV构建目录...${NC}"
    rm -rf "$OPENCV_BUILD_DIR"/*
    mkdir -p "$OPENCV_BUILD_DIR"
fi

# 进入构建目录
cd "$OPENCV_BUILD_DIR"

# 读取cmake选项到数组
CMAKE_OPTIONS=()
while read -r line; do
    if [[ ! -z "$line" && ! "$line" =~ ^# ]]; then
        CMAKE_OPTIONS+=("$line")
        # echo "$line"
    fi
done < "$OPENCV_SRC_DIR/options.txt"

# 构建CMake命令
CMAKE_CMD="CC='zig cc' CXX='zig c++' cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
CMAKE_CMD="$CMAKE_CMD -DCMAKE_BUILD_TYPE=$BUILD_TYPE"

# 添加额外选项
for option in "${CMAKE_OPTIONS[@]}"; do
    CMAKE_CMD="$CMAKE_CMD $option"
done
# echo "$CMAKE_CMD"
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
if [ $? -eq 0 ]; then
    echo -e "${GREEN}编译成功，开始安装...${NC}"
    make install
    
    # 检查安装结果
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}安装成功!${NC}"
        echo -e "${GREEN}OpenCV库文件位于: $INSTALL_DIR/lib/${NC}"
        echo -e "${GREEN}OpenCV头文件位于: $INSTALL_DIR/include/opencv4/${NC}"
        
        # 返回到项目根目录
        cd $PROJECT_ROOT_DIR
        
        # 编译主项目
        echo -e "${GREEN}正在编译主项目...${NC}"
        
        # 创建主项目构建目录
        mkdir -p build
        cd build
        
        # 配置主项目
        echo -e "${GREEN}配置主项目...${NC}"
        CMAKE_PROJECT_CMD="cmake .. -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DDUANGU_ENABLE_OPENCV=ON -DOpenCV_DIR=$INSTALL_DIR/lib/cmake/opencv4"
        echo -e "${GREEN}执行: $CMAKE_PROJECT_CMD${NC}"
        eval "$CMAKE_PROJECT_CMD"
        
        # 编译主项目
        echo -e "${GREEN}编译主项目...${NC}"
        make -j$(nproc)
        
        # 检查编译结果
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}主项目编译成功!${NC}"
            echo -e "${GREEN}库文件位于: build/lib/${NC}"
            echo -e "${GREEN}测试程序位于: build/bin/${NC}"
        else
            echo -e "${RED}主项目编译失败!${NC}"
            exit 1
        fi
    else
        echo -e "${RED}安装OpenCV失败!${NC}"
        exit 1
    fi
else
    echo -e "${RED}编译OpenCV失败!${NC}"
    exit 1
fi 
