#!/usr/bin/env bash
# =============================================================================
# build_xcframework.sh
# 为 uchardet 构建支持多 Apple 平台的 XCFramework
#
# 支持平台：
#   - iOS 13+              (arm64)
#   - iOS Simulator 13+    (arm64 + x86_64)
#   - macOS 10.15+         (arm64 + x86_64)
#   - Mac Catalyst 13+     (arm64 + x86_64)
#   - tvOS 13+             (arm64)
#   - tvOS Simulator 13+   (arm64 + x86_64)
#   - watchOS 6+           (arm64_32 + armv7k)
#   - watchOS Simulator 6+ (arm64 + x86_64)
#   - visionOS 1+          (arm64)
#   - visionOS Simulator 1+(arm64 + x86_64)
#
# Swift 支持：
#   脚本会自动在每个平台的 headers 目录中生成：
#     - uchardet.h          (umbrella header，汇总所有公开头文件)
#     - module.modulemap    (Clang 模块映射，使 Swift 可直接 import uchardet)
#   构建完成后即可在 Swift 中使用：
#     import uchardet
#
# 用法：
#   chmod +x build_xcframework.sh
#   ./build_xcframework.sh
#
# 可选环境变量：
#   BUILD_DIR      - 构建临时目录（默认：./build_xcframework_tmp）
#   OUTPUT_DIR     - 输出目录（默认：./output）
#   SKIP_PLATFORMS - 跳过的平台，逗号分隔（如：watchos,visionos）
#   KEEP_BUILD_DIR - 设为 1 时保留临时构建目录
# =============================================================================

set -euo pipefail

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $*${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# ── 路径配置 ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build_xcframework_tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/output}"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/uchardet.xcframework"
SKIP_PLATFORMS="${SKIP_PLATFORMS:-}"

# ── 版本配置 ──────────────────────────────────────────────────────────────────
IOS_DEPLOYMENT_TARGET="13.0"
MACOS_DEPLOYMENT_TARGET="10.15"
TVOS_DEPLOYMENT_TARGET="13.0"
WATCHOS_DEPLOYMENT_TARGET="6.0"
VISIONOS_DEPLOYMENT_TARGET="1.0"
# Mac Catalyst 最低版本：Xcode 16+ 的 clang 不支持 ios13.0-macabi，最低为 14.0
MACCATALYST_DEPLOYMENT_TARGET="14.0"

# ── 工具检查 ──────────────────────────────────────────────────────────────────
check_requirements() {
    log_step "检查构建依赖"

    local missing=0

    for tool in cmake xcodebuild lipo xcrun; do
        if command -v "${tool}" &>/dev/null; then
            log_success "${tool} 已找到: $(command -v ${tool})"
        else
            log_error "${tool} 未找到，请先安装"
            missing=$((missing + 1))
        fi
    done

    # 检查 Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode Command Line Tools 未安装，请运行: xcode-select --install"
        missing=$((missing + 1))
    else
        log_success "Xcode: $(xcode-select -p)"
    fi

    if [[ ${missing} -gt 0 ]]; then
        log_error "缺少 ${missing} 个依赖工具，退出"
        exit 1
    fi

    # 检查可用 SDK
    log_info "检查可用 SDK..."
    AVAILABLE_SDKS=$(xcodebuild -showsdks 2>/dev/null || true)
}

# ── 判断平台是否跳过 ──────────────────────────────────────────────────────────
should_skip() {
    local platform="$1"
    if [[ -n "${SKIP_PLATFORMS}" ]]; then
        IFS=',' read -ra SKIP_LIST <<< "${SKIP_PLATFORMS}"
        for skip in "${SKIP_LIST[@]}"; do
            if [[ "${platform}" == "${skip// /}" ]]; then
                return 0
            fi
        done
    fi
    return 1
}

# ── 判断 SDK 是否可用 ─────────────────────────────────────────────────────────
sdk_available() {
    local sdk="$1"
    xcrun --sdk "${sdk}" --show-sdk-path &>/dev/null
}

# ── 核心构建函数 ──────────────────────────────────────────────────────────────
# 参数：
#   $1 - 平台标识（用于目录命名）
#   $2 - CMake 系统名称
#   $3 - SDK 名称（传给 xcrun）
#   $4 - 架构列表（空格分隔，多架构时先分别编译再 lipo 合并）
#   $5 - 最低部署版本
#   $6 - 额外 CMake 参数（可选）
build_platform() {
    local PLATFORM_ID="$1"
    local CMAKE_SYSTEM_NAME="$2"
    local SDK_NAME="$3"
    local ARCHS="$4"
    local DEPLOYMENT_TARGET="$5"
    local EXTRA_CMAKE_ARGS="${6:-}"

    if should_skip "${PLATFORM_ID}"; then
        log_warn "跳过平台: ${PLATFORM_ID}"
        return 0
    fi

    if ! sdk_available "${SDK_NAME}"; then
        log_warn "SDK '${SDK_NAME}' 不可用，跳过平台: ${PLATFORM_ID}"
        return 0
    fi

    log_step "构建平台: ${PLATFORM_ID} [${ARCHS}]"

    local SDK_PATH
    SDK_PATH=$(xcrun --sdk "${SDK_NAME}" --show-sdk-path)
    log_info "SDK 路径: ${SDK_PATH}"

    local ARCH_ARRAY
    read -ra ARCH_ARRAY <<< "${ARCHS}"

    if [[ ${#ARCH_ARRAY[@]} -eq 1 ]]; then
        # 单架构直接构建
        _build_single_arch \
            "${PLATFORM_ID}" \
            "${CMAKE_SYSTEM_NAME}" \
            "${SDK_NAME}" \
            "${SDK_PATH}" \
            "${ARCH_ARRAY[0]}" \
            "${DEPLOYMENT_TARGET}" \
            "${EXTRA_CMAKE_ARGS}"

        local SINGLE_LIB="${BUILD_DIR}/${PLATFORM_ID}_${ARCH_ARRAY[0]}/lib/libuchardet.a"
        mkdir -p "${BUILD_DIR}/${PLATFORM_ID}/lib"
        cp "${SINGLE_LIB}" "${BUILD_DIR}/${PLATFORM_ID}/lib/libuchardet.a"
    else
        # 多架构：分别构建后 lipo 合并
        local LIPO_INPUTS=()
        for ARCH in "${ARCH_ARRAY[@]}"; do
            _build_single_arch \
                "${PLATFORM_ID}" \
                "${CMAKE_SYSTEM_NAME}" \
                "${SDK_NAME}" \
                "${SDK_PATH}" \
                "${ARCH}" \
                "${DEPLOYMENT_TARGET}" \
                "${EXTRA_CMAKE_ARGS}"
            LIPO_INPUTS+=("${BUILD_DIR}/${PLATFORM_ID}_${ARCH}/lib/libuchardet.a")
        done

        mkdir -p "${BUILD_DIR}/${PLATFORM_ID}/lib"
        log_info "lipo 合并架构: ${ARCHS}"
        lipo -create "${LIPO_INPUTS[@]}" \
             -output "${BUILD_DIR}/${PLATFORM_ID}/lib/libuchardet.a"
    fi

    # 复制头文件（只需做一次）
    local FIRST_ARCH="${ARCH_ARRAY[0]}"
    local HEADERS_SRC="${BUILD_DIR}/${PLATFORM_ID}_${FIRST_ARCH}/include"
    if [[ -d "${HEADERS_SRC}" ]]; then
        cp -R "${HEADERS_SRC}" "${BUILD_DIR}/${PLATFORM_ID}/include"
    fi

    log_success "平台 ${PLATFORM_ID} 构建完成"
}

# 内部：构建单一架构
_build_single_arch() {
    local PLATFORM_ID="$1"
    local CMAKE_SYSTEM_NAME="$2"
    local SDK_NAME="$3"
    local SDK_PATH="$4"
    local ARCH="$5"
    local DEPLOYMENT_TARGET="$6"
    local EXTRA_CMAKE_ARGS="$7"

    local BUILD_SUBDIR="${BUILD_DIR}/${PLATFORM_ID}_${ARCH}"
    mkdir -p "${BUILD_SUBDIR}"

    log_info "  构建 ${PLATFORM_ID} / ${ARCH} ..."

    # ── 构建编译器 flags 和 CMake 参数 ──────────────────────────────────────────
    local COMMON_FLAGS=""
    local EXTRA_TARGET_ARGS=""

    if [[ "${PLATFORM_ID}" == maccatalyst* ]]; then
        # Mac Catalyst：通过 -target <arch>-apple-ios<ver>-macabi 指定目标三元组。
        # 故意将 CMAKE_OSX_DEPLOYMENT_TARGET 设为空字符串，以阻止 CMake 自动注入
        # -mmacosx-version-min 标志（该标志会与 -target ...-macabi 产生冲突）。
        local CATALYST_TARGET="${ARCH}-apple-ios${DEPLOYMENT_TARGET}-macabi"
        EXTRA_TARGET_ARGS="-DCMAKE_C_COMPILER_TARGET=${CATALYST_TARGET} \
            -DCMAKE_CXX_COMPILER_TARGET=${CATALYST_TARGET} \
            -DCMAKE_OSX_SYSROOT=${SDK_PATH} \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
            -DCMAKE_OSX_DEPLOYMENT_TARGET="
        COMMON_FLAGS="-isysroot ${SDK_PATH}"
    elif [[ "${CMAKE_SYSTEM_NAME}" == "xrOS" ]]; then
        # visionOS：使用 compiler target triple
        local XROS_TARGET
        if [[ "${SDK_NAME}" == *simulator* ]]; then
            XROS_TARGET="${ARCH}-apple-xros${DEPLOYMENT_TARGET}-simulator"
        else
            XROS_TARGET="${ARCH}-apple-xros${DEPLOYMENT_TARGET}"
        fi
        EXTRA_TARGET_ARGS="-DCMAKE_C_COMPILER_TARGET=${XROS_TARGET} \
            -DCMAKE_CXX_COMPILER_TARGET=${XROS_TARGET} \
            -DCMAKE_OSX_SYSROOT=${SDK_PATH} \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH}"
        COMMON_FLAGS="-isysroot ${SDK_PATH}"
    else
        # 其他平台：使用 -arch + -isysroot + -m<platform>-version-min
        COMMON_FLAGS="-arch ${ARCH} -isysroot ${SDK_PATH}"
        local DEPLOYMENT_FLAG=""
        case "${CMAKE_SYSTEM_NAME}" in
            iOS)
                if [[ "${SDK_NAME}" == *simulator* ]]; then
                    DEPLOYMENT_FLAG="-mios-simulator-version-min=${DEPLOYMENT_TARGET}"
                else
                    DEPLOYMENT_FLAG="-miphoneos-version-min=${DEPLOYMENT_TARGET}"
                fi
                ;;
            tvOS)
                if [[ "${SDK_NAME}" == *simulator* ]]; then
                    DEPLOYMENT_FLAG="-mtvos-simulator-version-min=${DEPLOYMENT_TARGET}"
                else
                    DEPLOYMENT_FLAG="-mtvos-version-min=${DEPLOYMENT_TARGET}"
                fi
                ;;
            watchOS)
                if [[ "${SDK_NAME}" == *simulator* ]]; then
                    DEPLOYMENT_FLAG="-mwatchos-simulator-version-min=${DEPLOYMENT_TARGET}"
                else
                    DEPLOYMENT_FLAG="-mwatchos-version-min=${DEPLOYMENT_TARGET}"
                fi
                ;;
            Darwin)
                DEPLOYMENT_FLAG="-mmacosx-version-min=${DEPLOYMENT_TARGET}"
                ;;
        esac
        if [[ -n "${DEPLOYMENT_FLAG}" ]]; then
            COMMON_FLAGS="${COMMON_FLAGS} ${DEPLOYMENT_FLAG}"
        fi
        EXTRA_TARGET_ARGS="-DCMAKE_OSX_SYSROOT=${SDK_PATH} \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH}"
    fi

    local INSTALL_PREFIX="${BUILD_SUBDIR}"

    # shellcheck disable=SC2086
    cmake -S "${SOURCE_DIR}" \
          -B "${BUILD_SUBDIR}/cmake_build" \
          -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
          -DBUILD_BINARY=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_STATIC=ON \
          -DCHECK_SSE2=OFF \
          -DCMAKE_SYSTEM_NAME="${CMAKE_SYSTEM_NAME}" \
          -DCMAKE_C_FLAGS="${COMMON_FLAGS}" \
          -DCMAKE_CXX_FLAGS="${COMMON_FLAGS}" \
          -DCMAKE_C_COMPILER="$(xcrun --sdk ${SDK_NAME} --find clang)" \
          -DCMAKE_CXX_COMPILER="$(xcrun --sdk ${SDK_NAME} --find clang++)" \
          -DCMAKE_AR="$(xcrun --sdk ${SDK_NAME} --find ar)" \
          -DCMAKE_RANLIB="$(xcrun --sdk ${SDK_NAME} --find ranlib)" \
          ${EXTRA_TARGET_ARGS} \
          ${EXTRA_CMAKE_ARGS} \
          -DCMAKE_INSTALL_LIBDIR=lib \
          -DCMAKE_INSTALL_INCLUDEDIR=include \
          > "${BUILD_SUBDIR}/cmake_configure.log" 2>&1

    cmake --build "${BUILD_SUBDIR}/cmake_build" \
          --config Release \
          --target libuchardet \
          -- -j"$(sysctl -n hw.logicalcpu)" \
          > "${BUILD_SUBDIR}/cmake_build.log" 2>&1

    cmake --install "${BUILD_SUBDIR}/cmake_build" \
          --config Release \
          > "${BUILD_SUBDIR}/cmake_install.log" 2>&1

    log_success "  ${PLATFORM_ID} / ${ARCH} 完成"
}

# ── 生成 Swift/Clang 模块支持文件 ─────────────────────────────────────────────
# 在每个平台的 include 目录中写入：
#   1. uchardet/uchardet.h  —— umbrella header（汇总公开 API）
#   2. module.modulemap     —— Clang 模块映射（Swift import 入口）
generate_module_support() {
    log_step "生成 Swift 模块支持文件（module.modulemap）"

    local PLATFORM_IDS=(
        "ios"
        "ios_simulator"
        "macos"
        "maccatalyst"
        "tvos"
        "tvos_simulator"
        "watchos"
        "watchos_simulator"
        "visionos"
        "visionos_simulator"
    )

    for PLATFORM_ID in "${PLATFORM_IDS[@]}"; do
        local HEADERS_DIR="${BUILD_DIR}/${PLATFORM_ID}/include"

        # 跳过未构建的平台
        if [[ ! -d "${HEADERS_DIR}" ]]; then
            continue
        fi

        log_info "为平台 ${PLATFORM_ID} 生成模块文件..."

        # ── 1. 创建 uchardet 子目录（XCFramework 约定：headers/<ModuleName>/）
        local MODULE_HEADERS_DIR="${HEADERS_DIR}/uchardet"
        mkdir -p "${MODULE_HEADERS_DIR}"

        # 将 uchardet.h 移入子目录（如果还在顶层）
        if [[ -f "${HEADERS_DIR}/uchardet.h" && ! -f "${MODULE_HEADERS_DIR}/uchardet.h" ]]; then
            cp "${HEADERS_DIR}/uchardet.h" "${MODULE_HEADERS_DIR}/uchardet.h"
        fi

        # ── 2. 生成 umbrella header（uchardet/uchardet.h 已是公开 API 的全集）
        #       如果将来有多个头文件，在此处 #include 即可
        cat > "${MODULE_HEADERS_DIR}/uchardet-umbrella.h" <<'UMBRELLA_EOF'
//
// uchardet-umbrella.h
// 自动生成 —— 请勿手动修改
//
// 此文件作为 Clang 模块的 umbrella header，
// 汇总 uchardet 库的全部公开 C API。
// Swift 代码通过 `import uchardet` 即可访问以下接口：
//
//   uchardet_t  uchardet_new(void)
//   void        uchardet_delete(uchardet_t ud)
//   int         uchardet_handle_data(uchardet_t ud, const char *data, size_t len)
//   void        uchardet_data_end(uchardet_t ud)
//   void        uchardet_reset(uchardet_t ud)
//   const char *uchardet_get_charset(uchardet_t ud)
//

#ifndef UCHARDET_UMBRELLA_H
#define UCHARDET_UMBRELLA_H

#include "uchardet.h"

#endif /* UCHARDET_UMBRELLA_H */
UMBRELLA_EOF

        # ── 3. 生成 module.modulemap
        # 注意：必须使用 `module`（而非 `framework module`）
        # 因为这是静态库（.a），不是 framework bundle。
        # SPM binaryTarget 处理静态库 xcframework 时，
        # `framework module` 会导致 umbrella header 路径解析失败。
        cat > "${HEADERS_DIR}/module.modulemap" <<'MODULEMAP_EOF'
//
// module.modulemap
// 自动生成 —— 请勿手动修改
//
// Clang 模块映射文件，使 Swift 和 Objective-C 代码可以通过
//   import uchardet
// 直接使用 uchardet 库的 C API。
//
module uchardet {
    umbrella header "uchardet/uchardet-umbrella.h"

    export *
    module * { export * }
}
MODULEMAP_EOF
        log_success "  ${PLATFORM_ID}: module.modulemap 已生成"
    done

    log_success "所有平台模块文件生成完毕"
}

# ── 组装 XCFramework ──────────────────────────────────────────────────────────
assemble_xcframework() {
    log_step "组装 XCFramework"

    # 收集所有已构建平台的参数
    local XCODE_ARGS=()

    # 定义所有可能的平台目录和对应的 headers 路径
    declare -a PLATFORM_IDS=(
        "ios"
        "ios_simulator"
        "macos"
        "maccatalyst"
        "tvos"
        "tvos_simulator"
        "watchos"
        "watchos_simulator"
        "visionos"
        "visionos_simulator"
    )

    for PLATFORM_ID in "${PLATFORM_IDS[@]}"; do
        local LIB_PATH="${BUILD_DIR}/${PLATFORM_ID}/lib/libuchardet.a"
        local HEADERS_PATH="${BUILD_DIR}/${PLATFORM_ID}/include"

        if [[ -f "${LIB_PATH}" ]]; then
            log_info "添加平台: ${PLATFORM_ID}"
            XCODE_ARGS+=(-library "${LIB_PATH}" -headers "${HEADERS_PATH}")
        else
            log_warn "平台 ${PLATFORM_ID} 未构建，跳过"
        fi
    done

    if [[ ${#XCODE_ARGS[@]} -eq 0 ]]; then
        log_error "没有任何平台被成功构建，无法创建 XCFramework"
        exit 1
    fi

    # 删除旧的 xcframework
    rm -rf "${XCFRAMEWORK_PATH}"
    mkdir -p "${OUTPUT_DIR}"

    log_info "运行 xcodebuild -create-xcframework ..."
    xcodebuild -create-xcframework \
        "${XCODE_ARGS[@]}" \
        -output "${XCFRAMEWORK_PATH}"

    log_success "XCFramework 已生成: ${XCFRAMEWORK_PATH}"
}

# ── 打印摘要 ──────────────────────────────────────────────────────────────────
print_summary() {
    log_step "构建摘要"

    if [[ -d "${XCFRAMEWORK_PATH}" ]]; then
        log_success "uchardet.xcframework 构建成功！"
        echo ""
        echo "  输出路径: ${XCFRAMEWORK_PATH}"
        echo ""
        echo "  包含平台:"
        # 列出 xcframework 内的 slice 目录
        for slice_dir in "${XCFRAMEWORK_PATH}"/*/; do
            if [[ -d "${slice_dir}" ]]; then
                local slice_name
                slice_name=$(basename "${slice_dir}")
                echo "    • ${slice_name}"
            fi
        done
        echo ""
        echo "  Swift 使用方式："
        echo "    1. 将 uchardet.xcframework 拖入 Xcode 项目"
        echo "       （或在 Package.swift 的 binaryTarget 中引用）"
        echo "    2. 在 Swift 文件中直接导入："
        echo "         import uchardet"
        echo ""
        echo "    Swift 示例代码："
        echo "         let detector = uchardet_new()"
        echo "         defer { uchardet_delete(detector) }"
        echo "         let data = \"Hello, 世界\""
        echo "         data.withCString { ptr in"
        echo "             uchardet_handle_data(detector, ptr, strlen(ptr))"
        echo "         }"
        echo "         uchardet_data_end(detector)"
        echo "         let charset = String(cString: uchardet_get_charset(detector)!)"
        echo "         print(\"检测到编码: \\(charset)\")"
        echo ""
        # 显示文件大小
        local SIZE
        SIZE=$(du -sh "${XCFRAMEWORK_PATH}" | cut -f1)
        echo "  框架大小: ${SIZE}"
    else
        log_error "XCFramework 未生成，请检查上方错误信息"
        exit 1
    fi
}

# ── 清理函数 ──────────────────────────────────────────────────────────────────
cleanup() {
    if [[ "${KEEP_BUILD_DIR:-0}" != "1" ]]; then
        log_info "清理临时构建目录..."
        rm -rf "${BUILD_DIR}"
    else
        log_info "保留临时构建目录: ${BUILD_DIR}"
    fi
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     uchardet XCFramework 构建脚本 v1.0           ║${NC}"
    echo -e "${CYAN}║     支持 iOS 13+ 及同期 Apple 平台               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # 记录开始时间
    local START_TIME
    START_TIME=$(date +%s)

    check_requirements

    # 创建构建目录
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${OUTPUT_DIR}"

    # ── iOS (arm64) ────────────────────────────────────────────────────────────
    build_platform \
        "ios" \
        "iOS" \
        "iphoneos" \
        "arm64" \
        "${IOS_DEPLOYMENT_TARGET}"

    # ── iOS Simulator (arm64 + x86_64) ────────────────────────────────────────
    build_platform \
        "ios_simulator" \
        "iOS" \
        "iphonesimulator" \
        "arm64 x86_64" \
        "${IOS_DEPLOYMENT_TARGET}"

    # ── macOS (arm64 + x86_64) ────────────────────────────────────────────────
    build_platform \
        "macos" \
        "Darwin" \
        "macosx" \
        "arm64 x86_64" \
        "${MACOS_DEPLOYMENT_TARGET}"

    # ── Mac Catalyst (arm64 + x86_64) ─────────────────────────────────────────
    # CMAKE_SYSTEM_NAME=Darwin 避免 CMake 自动注入 iOS deployment flag
    # 编译 flags 中通过 -target ...-macabi 指定 Catalyst 目标
    build_platform \
        "maccatalyst" \
        "Darwin" \
        "macosx" \
        "arm64 x86_64" \
        "${MACCATALYST_DEPLOYMENT_TARGET}"

    # ── tvOS (arm64) ──────────────────────────────────────────────────────────
    build_platform \
        "tvos" \
        "tvOS" \
        "appletvos" \
        "arm64" \
        "${TVOS_DEPLOYMENT_TARGET}"

    # ── tvOS Simulator (arm64 + x86_64) ───────────────────────────────────────
    build_platform \
        "tvos_simulator" \
        "tvOS" \
        "appletvsimulator" \
        "arm64 x86_64" \
        "${TVOS_DEPLOYMENT_TARGET}"

    # ── watchOS (arm64_32 + armv7k) ───────────────────────────────────────────
    build_platform \
        "watchos" \
        "watchOS" \
        "watchos" \
        "arm64_32 armv7k" \
        "${WATCHOS_DEPLOYMENT_TARGET}"

    # ── watchOS Simulator (arm64 + x86_64) ────────────────────────────────────
    build_platform \
        "watchos_simulator" \
        "watchOS" \
        "watchsimulator" \
        "arm64 x86_64" \
        "${WATCHOS_DEPLOYMENT_TARGET}"

    # ── visionOS (arm64) ──────────────────────────────────────────────────────
    build_platform \
        "visionos" \
        "xrOS" \
        "xros" \
        "arm64" \
        "${VISIONOS_DEPLOYMENT_TARGET}"

    # ── visionOS Simulator (arm64 + x86_64) ───────────────────────────────────
    build_platform \
        "visionos_simulator" \
        "xrOS" \
        "xrsimulator" \
        "arm64 x86_64" \
        "${VISIONOS_DEPLOYMENT_TARGET}"

    # ── 生成 Swift 模块支持文件 ────────────────────────────────────────────────
    generate_module_support

    # ── 组装 XCFramework ───────────────────────────────────────────────────────
    assemble_xcframework

    # ── 清理 ───────────────────────────────────────────────────────────────────
    cleanup

    # ── 打印摘要 ───────────────────────────────────────────────────────────────
    print_summary

    # 计算耗时
    local END_TIME
    END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local MINUTES=$((ELAPSED / 60))
    local SECONDS=$((ELAPSED % 60))
    echo -e "  总耗时: ${MINUTES}m ${SECONDS}s"
    echo ""
}

# ── 处理命令行参数 ────────────────────────────────────────────────────────────
case "${1:-}" in
    --help|-h)
        cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --help, -h          显示此帮助信息
  --clean             仅清理构建目录
  --output <路径>     指定输出目录（默认: ./output）
  --skip <平台列表>   跳过指定平台（逗号分隔）
                      可用值: ios, ios_simulator, macos, maccatalyst,
                               tvos, tvos_simulator, watchos, watchos_simulator,
                               visionos, visionos_simulator

环境变量:
  BUILD_DIR           临时构建目录（默认: ./build_xcframework_tmp）
  OUTPUT_DIR          输出目录（默认: ./output）
  SKIP_PLATFORMS      跳过的平台（逗号分隔）
  KEEP_BUILD_DIR      设为 1 时保留临时构建目录

示例:
  # 完整构建
  ./build_xcframework.sh

  # 仅构建 iOS 和 macOS
  SKIP_PLATFORMS=tvos,tvos_simulator,watchos,watchos_simulator,visionos,visionos_simulator \\
    ./build_xcframework.sh

  # 指定输出目录并保留构建目录
  OUTPUT_DIR=~/Desktop/xcframeworks KEEP_BUILD_DIR=1 ./build_xcframework.sh
EOF
        exit 0
        ;;
    --clean)
        log_info "清理构建目录: ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"
        log_info "清理输出目录: ${OUTPUT_DIR}"
        rm -rf "${OUTPUT_DIR}"
        log_success "清理完成"
        exit 0
        ;;
    --output)
        OUTPUT_DIR="${2:?'--output 需要指定路径'}"
        XCFRAMEWORK_PATH="${OUTPUT_DIR}/uchardet.xcframework"
        shift 2
        main
        ;;
    --skip)
        SKIP_PLATFORMS="${2:?'--skip 需要指定平台列表'}"
        shift 2
        main
        ;;
    "")
        main
        ;;
    *)
        log_error "未知参数: $1，使用 --help 查看帮助"
        exit 1
        ;;
esac
