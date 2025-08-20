#!/bin/sh
# cli.sh - fake_system_version 命令行工具
# 用于方便地设置环境变量并启动目标程序
#
# 使用示例:
# ./cli.sh \
#   --os-version 15.4.1 \
#   --build-version 24E263 \
#   --kernel-release 24.4.0 \
#   --machine arm64 \
#   --hw-model "MacBookAir10,1" \
#   --enable-log \
#   -- /opt/homebrew/bin/fastfetch
#
# 或者使用分离的版本号:
# ./cli.sh \
#   --os-major 15 --os-minor 4 --os-patch 1 \
#   --auto-product-name \
#   -- fastfetch

# ===================================================================================
# 默认配置值 (与 fake_system_version.mm 中的默认值保持一致)
# ===================================================================================

# === 系统版本配置 ===
FAKE_OS_MAJOR="15"
FAKE_OS_MINOR="4"
FAKE_OS_PATCH="1"
FAKE_OS_BUILD="24E263"

# === Darwin 内核配置 ===
FAKE_KERNEL_RELEASE="24.4.0"
FAKE_KERNEL_VERSION="Darwin Kernel Version 24.4.0: Fri Apr 11 18:32:50 PDT 2025; root:xnu-11417.101.15~117/RELEASE_ARM64_T6041"

# === 硬件架构配置 ===
FAKE_MACHINE="arm64"

# === 硬件信息配置 (默认为空，表示不修改) ===
FAKE_HW_MODEL=""
FAKE_HW_MACHINE=""
FAKE_HW_MEMSIZE=""

# === 功能开关 ===
FAKE_ENABLE_LOG="1"        # 默认启用日志
FAKE_AUTO_PRODUCT_NAME="1" # 默认启用自动产品名称判断

# ===================================================================================
# 帮助信息
# ===================================================================================

show_help() {
    cat << 'EOF'
fake_system_version CLI 工具

用法: ./cli.sh [选项] -- <目标程序> [程序参数...]

系统版本选项:
  --os-version VERSION          设置完整版本号 (如: 15.4.1)
  --os-major MAJOR              设置主版本号 (如: 15)
  --os-minor MINOR              设置次版本号 (如: 4)  
  --os-patch PATCH              设置补丁版本号 (如: 1)
  --build-version BUILD         设置构建版本 (如: 24E263)

Darwin 内核选项:
  --kernel-release RELEASE      设置内核发布版本 (如: 24.4.0)
  --kernel-version VERSION      设置完整内核版本字符串

硬件架构选项:
  --machine ARCH                设置机器架构 (如: arm64, x86_64)

硬件信息选项 (默认不修改):
  --hw-model MODEL              设置硬件机器类型 (如: "MacBookPro18,1")
  --hw-machine MACHINE          设置机器架构 (如: arm64, x86_64)
  --hw-memsize SIZE             设置内存大小 (如: "17179869184")

功能开关:
  --enable-log                  启用日志输出 (默认)
  --disable-log                 禁用日志输出
  --auto-product-name           启用自动产品名称判断 (默认)
  --no-auto-product-name        禁用自动产品名称判断

其他选项:
  -h, --help                    显示此帮助信息
  --                            标记选项结束，后面是目标程序

环境变量支持:
  所有选项都可以通过对应的环境变量设置:
  FAKE_OS_MAJOR, FAKE_OS_MINOR, FAKE_OS_PATCH, FAKE_OS_VERSION
  FAKE_OS_BUILD, FAKE_KERNEL_RELEASE, FAKE_KERNEL_VERSION
  FAKE_MACHINE, FAKE_HW_MODEL, FAKE_HW_MACHINE, FAKE_HW_MEMSIZE
  FAKE_ENABLE_LOG, FAKE_AUTO_PRODUCT_NAME

使用示例:
  # 基本用法
  ./cli.sh --os-version 15.4.1 -- sw_vers
  
  # 完整配置
  ./cli.sh \
    --os-major 15 --os-minor 4 --os-patch 1 \
    --build-version 24E263 \
    --kernel-release 24.4.0 \
    --machine arm64 \
    --hw-model "MacBookAir10,1" \
    --enable-log \
    -- system_profiler SPSoftwareDataType
  
  # 禁用日志的静默模式
  ./cli.sh --disable-log --os-version 14.5 -- fastfetch
  
  # 模拟旧版本 Mac OS X
  ./cli.sh \
    --os-version 10.15.7 \
    --no-auto-product-name \
    -- sw_vers

EOF
}

# ===================================================================================
# 参数解析
# ===================================================================================

# 检查是否需要显示帮助
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# 解析命令行参数
while [ $# -gt 0 ]; do
    case "$1" in
        # === 帮助信息 ===
        -h|--help)
            show_help
            exit 0
            ;;
            
        # === 系统版本选项 ===
        --os-version)
            if [ -z "$2" ]; then
                echo "错误: --os-version 需要指定版本号" >&2
                exit 1
            fi
            FAKE_OS_VERSION="$2"
            # 清空分离的版本号，优先使用完整版本号
            unset FAKE_OS_MAJOR FAKE_OS_MINOR FAKE_OS_PATCH
            shift 2
            ;;
        --os-major)
            if [ -z "$2" ]; then
                echo "错误: --os-major 需要指定主版本号" >&2
                exit 1
            fi
            FAKE_OS_MAJOR="$2"
            # 清空完整版本号，使用分离的版本号
            unset FAKE_OS_VERSION
            shift 2
            ;;
        --os-minor)
            if [ -z "$2" ]; then
                echo "错误: --os-minor 需要指定次版本号" >&2
                exit 1
            fi
            FAKE_OS_MINOR="$2"
            unset FAKE_OS_VERSION
            shift 2
            ;;
        --os-patch)
            if [ -z "$2" ]; then
                echo "错误: --os-patch 需要指定补丁版本号" >&2
                exit 1
            fi
            FAKE_OS_PATCH="$2"
            unset FAKE_OS_VERSION
            shift 2
            ;;
        --build-version)
            if [ -z "$2" ]; then
                echo "错误: --build-version 需要指定构建版本" >&2
                exit 1
            fi
            FAKE_OS_BUILD="$2"
            shift 2
            ;;
            
        # === Darwin 内核选项 ===
        --kernel-release)
            if [ -z "$2" ]; then
                echo "错误: --kernel-release 需要指定内核版本" >&2
                exit 1
            fi
            FAKE_KERNEL_RELEASE="$2"
            shift 2
            ;;
        --kernel-version)
            if [ -z "$2" ]; then
                echo "错误: --kernel-version 需要指定完整内核版本" >&2
                exit 1
            fi
            FAKE_KERNEL_VERSION="$2"
            shift 2
            ;;
            
        # === 硬件架构选项 ===
        --machine)
            if [ -z "$2" ]; then
                echo "错误: --machine 需要指定架构类型" >&2
                exit 1
            fi
            FAKE_MACHINE="$2"
            shift 2
            ;;
            
        # === 硬件信息选项 ===
        --hw-model)
            if [ -z "$2" ]; then
                echo "错误: --hw-model 需要指定硬件型号" >&2
                exit 1
            fi
            FAKE_HW_MODEL="$2"
            shift 2
            ;;
        --hw-machine)
            if [ -z "$2" ]; then
                echo "错误: --hw-machine 需要指定硬件机器类型" >&2
                exit 1
            fi
            FAKE_HW_MACHINE="$2"
            shift 2
            ;;
        --hw-memsize)
            if [ -z "$2" ]; then
                echo "错误: --hw-memsize 需要指定内存大小" >&2
                exit 1
            fi
            FAKE_HW_MEMSIZE="$2"
            shift 2
            ;;
            
        # === 功能开关 ===
        --enable-log)
            FAKE_ENABLE_LOG="1"
            shift
            ;;
        --disable-log)
            FAKE_ENABLE_LOG="0"
            shift
            ;;
        --auto-product-name)
            FAKE_AUTO_PRODUCT_NAME="1"
            shift
            ;;
        --no-auto-product-name)
            FAKE_AUTO_PRODUCT_NAME="0"
            shift
            ;;
            
        # === 选项结束标记 ===
        --)
            shift
            break
            ;;
            
        # === 未知选项 ===
        -*)
            echo "错误: 未知选项 '$1'" >&2
            echo "使用 --help 查看帮助信息" >&2
            exit 1
            ;;
            
        # === 没有 -- 分隔符的情况 ===
        *)
            echo "错误: 请使用 -- 分隔选项和目标程序" >&2
            echo "示例: $0 --os-version 15.4.1 -- sw_vers" >&2
            exit 1
            ;;
    esac
done

# 检查是否指定了目标程序
if [ $# -eq 0 ]; then
    echo "错误: 请指定要运行的目标程序" >&2
    echo "示例: $0 --os-version 15.4.1 -- sw_vers" >&2
    exit 1
fi

TARGET_PROG="$1"
shift
TARGET_ARGS="$@"

# ===================================================================================
# 环境变量设置和验证
# ===================================================================================

# 检查 dylib 文件是否存在
DYLIB_PATH="./fake_system_version.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
    echo "错误: 找不到 fake_system_version.dylib 文件" >&2
    echo "请确保在包含 .dylib 文件的目录中运行此脚本" >&2
    exit 1
fi

# 检查目标程序是否存在
if ! command -v "$TARGET_PROG" >/dev/null 2>&1; then
    echo "警告: 目标程序 '$TARGET_PROG' 可能不存在或不在 PATH 中" >&2
fi

# 设置所有环境变量
export FAKE_OS_MAJOR FAKE_OS_MINOR FAKE_OS_PATCH
export FAKE_OS_VERSION FAKE_OS_BUILD
export FAKE_KERNEL_RELEASE FAKE_KERNEL_VERSION
export FAKE_MACHINE
export FAKE_HW_MODEL FAKE_HW_MACHINE FAKE_HW_MEMSIZE
export FAKE_ENABLE_LOG FAKE_AUTO_PRODUCT_NAME

# 设置 DYLD_INSERT_LIBRARIES
export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"

# 如果启用了日志，显示配置信息
if [ "$FAKE_ENABLE_LOG" = "1" ]; then
    echo "[cli.sh] 配置信息:" >&2
    if [ -n "$FAKE_OS_VERSION" ]; then
        echo "[cli.sh]   系统版本: $FAKE_OS_VERSION (完整版本号)" >&2
    else
        echo "[cli.sh]   系统版本: $FAKE_OS_MAJOR.$FAKE_OS_MINOR.$FAKE_OS_PATCH (分离版本号)" >&2
    fi
    echo "[cli.sh]   构建版本: $FAKE_OS_BUILD" >&2
    echo "[cli.sh]   内核版本: $FAKE_KERNEL_RELEASE" >&2
    echo "[cli.sh]   机器架构: $FAKE_MACHINE" >&2
    
    if [ -n "$FAKE_HW_MODEL" ]; then
        echo "[cli.sh]   硬件型号: $FAKE_HW_MODEL" >&2
    fi
    if [ -n "$FAKE_HW_MACHINE" ]; then
        echo "[cli.sh]   硬件机器类型: $FAKE_HW_MACHINE" >&2
    fi
    if [ -n "$FAKE_HW_MEMSIZE" ]; then
        echo "[cli.sh]   内存大小: $FAKE_HW_MEMSIZE" >&2
    fi
    
    echo "[cli.sh]   自动产品名称: $([ "$FAKE_AUTO_PRODUCT_NAME" = "1" ] && echo "启用" || echo "禁用")" >&2
    echo "[cli.sh]   目标程序: $TARGET_PROG $TARGET_ARGS" >&2
    echo "[cli.sh] 正在启动目标程序..." >&2
fi

# ===================================================================================
# 启动目标程序
# ===================================================================================

# 将当前目录添加到 PATH 前面，以便 sw_vers 等命令优先使用自定义版本
export PATH="$(pwd):$PATH"

# 执行目标程序
exec "$TARGET_PROG" $TARGET_ARGS