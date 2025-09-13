#!/bin/bash

# Whisper 字幕识别脚本
# 用法:
# 1. 直接运行: ./whisper.sh --input <文件名> [--engine whisper|faster-whisper] [--model medium] [--language Chinese]
# 2. 管道调用: curl -fsSL https://raw.githubusercontent.com/ericwang2006/whisper-webui/refs/heads/main/whisper.sh | bash -s -- --input <文件名> [--engine whisper|faster-whisper] [--model medium] [--language Chinese]

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 清理函数
cleanup() {
    log_info "执行清理工作..."

    # 退出虚拟环境
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        log_info "退出Python虚拟环境"
        deactivate 2>/dev/null || true
    fi

    # 卸载镜像
    if mountpoint -q /content/whisperenv 2>/dev/null; then
        log_info "卸载镜像文件"
        fusermount -uz /content/whisperenv 2>/dev/null
    fi
}

# 设置退出时自动清理
trap cleanup EXIT

# 默认参数值
FILENAME=""
WHISPER_TYPE="whisper"
MODEL="medium"
LANGUAGE="Chinese"

# 解析命令行参数
# 当通过管道调用时，参数会通过 bash -s 传递，需要跳过第一个参数（脚本名）
while [[ $# -gt 0 ]]; do
    case $1 in
        --input)
            FILENAME="$2"
            shift 2
            ;;
        --engine)
            WHISPER_TYPE="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 --input <文件名> [--engine whisper|faster-whisper] [--model medium] [--language Chinese]"
            echo "管道调用: curl -fsSL https://raw.githubusercontent.com/ericwang2006/whisper-webui/refs/heads/main/whisper.sh | bash -s -- --input <文件名> [--engine whisper|faster-whisper] [--model medium] [--language Chinese]"
            echo "示例: curl -fsSL https://raw.githubusercontent.com/ericwang2006/whisper-webui/refs/heads/main/whisper.sh | bash -s -- --input 054.mp4 --engine whisper --model medium --language Chinese"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$FILENAME" ]; then
    log_error "缺少必需参数 --input"
    echo "使用 --help 查看帮助信息"
    exit 1
fi

log_info "参数设置: 文件名=$FILENAME, 识别引擎=$WHISPER_TYPE, 模型=$MODEL, 语言=$LANGUAGE"

# 1. 检查镜像文件是否存在
IMAGE_FILE="/content/drive/MyDrive/whisper/whisperenv.img"
if [ ! -f "$IMAGE_FILE" ]; then
    log_error "镜像文件不存在: $IMAGE_FILE"
    exit 1
fi
log_info "镜像文件检查通过: $IMAGE_FILE"

# 2. 挂载镜像文件
MOUNT_POINT="/content/whisperenv"

# 检查是否已经挂载
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    log_info "镜像已经挂载在: $MOUNT_POINT"
else
    log_info "开始挂载镜像文件..."

    # 更新包管理器并安装fuseext2
    log_info "更新系统包..."
    apt-get update -qq

    log_info "安装fuseext2..."
    apt-get install -y fuseext2

    # 创建挂载点
    mkdir -p "$MOUNT_POINT"

    # 挂载镜像
    log_info "挂载镜像文件到: $MOUNT_POINT"
    if ! fuseext2 "$IMAGE_FILE" "$MOUNT_POINT" -o ro; then
        log_error "挂载镜像文件失败"
        exit 1
    fi

    log_info "镜像挂载成功"
fi

# 3. 进入Python虚拟环境
VENV_ACTIVATE="/content/whisperenv/bin/activate"
if [ ! -f "$VENV_ACTIVATE" ]; then
    log_error "虚拟环境激活脚本不存在: $VENV_ACTIVATE"
    exit 1
fi

log_info "激活Python虚拟环境..."
source "$VENV_ACTIVATE"

if [[ "$VIRTUAL_ENV" == "" ]]; then
    log_error "虚拟环境激活失败"
    exit 1
fi
log_info "虚拟环境激活成功: $VIRTUAL_ENV"

# 4. 检查并创建缓存目录
CACHE_DIR="/content/drive/MyDrive/whisper/cache"
if [ ! -d "$CACHE_DIR" ]; then
    log_info "创建缓存目录: $CACHE_DIR"
    mkdir -p "$CACHE_DIR"
else
    log_info "缓存目录已存在: $CACHE_DIR"
fi

# 5. 检查并下载字幕识别程序
WEBUI_DIR="/content/drive/MyDrive/whisper/whisper-webui"
if [ ! -d "$WEBUI_DIR" ]; then
    log_warn "字幕识别程序目录不存在: $WEBUI_DIR"
    log_info "开始从GitHub下载whisper-webui..."

    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    ZIP_FILE="$TEMP_DIR/whisper-webui-main.zip"

    log_info "临时目录: $TEMP_DIR"
    log_info "下载压缩包到: $ZIP_FILE"

    # 下载压缩包
    if ! curl -s -L -o "$ZIP_FILE" "https://github.com/ericwang2006/whisper-webui/archive/refs/heads/main.zip"; then
        log_error "下载whisper-webui失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    log_info "下载完成，开始解压..."

    # 解压到临时目录
    if ! unzip -q "$ZIP_FILE" -d "$TEMP_DIR"; then
        log_error "解压whisper-webui失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # 创建目标目录的父目录
    mkdir -p "$(dirname "$WEBUI_DIR")"

    # 移动解压后的文件到目标目录
    if ! mv "$TEMP_DIR/whisper-webui-main" "$WEBUI_DIR"; then
        log_error "移动文件到目标目录失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # 清理临时目录
    rm -rf "$TEMP_DIR"

    log_info "whisper-webui下载和安装完成: $WEBUI_DIR"
else
    log_info "字幕识别程序目录已存在: $WEBUI_DIR"
fi

# 6. 进入字幕识别程序目录
log_info "切换到工作目录: $WEBUI_DIR"
cd "$WEBUI_DIR"

# 检查目标文件是否存在
MP4_DIR="/content/drive/MyDrive/whisper/mp4"
INPUT_FILE="$MP4_DIR/$FILENAME"

if [ ! -f "$INPUT_FILE" ]; then
    log_error "输入文件不存在: $INPUT_FILE"
    exit 1
fi
log_info "输入文件检查通过: $INPUT_FILE"

# 7. 检查显卡支持
HAS_GPU=false
if command -v nvidia-smi >/dev/null 2>&1; then
    log_info "检查NVIDIA显卡..."
    if nvidia-smi >/dev/null 2>&1; then
        # 检查是否有有效的GPU设备
        GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -n1)
        if [[ "$GPU_COUNT" =~ ^[0-9]+$ ]] && [ "$GPU_COUNT" -gt 0 ]; then
            HAS_GPU=true
            log_info "检测到 $GPU_COUNT 个NVIDIA显卡，启用GPU加速"
        else
            log_info "未检测到有效的NVIDIA显卡，使用CPU模式"
        fi
    else
        log_info "nvidia-smi命令执行失败，使用CPU模式"
    fi
else
    log_info "未找到nvidia-smi命令，使用CPU模式"
fi

# 8. 执行字幕识别功能
log_info "开始执行字幕识别，使用引擎: $WHISPER_TYPE, 模型: $MODEL, GPU加速: $HAS_GPU"

if [ "$WHISPER_TYPE" = "faster-whisper" ]; then
    log_info "使用 faster-whisper 引擎..."
    if [ "$HAS_GPU" = true ]; then
        # 有GPU时使用float16
        HF_HUB_CACHE="$CACHE_DIR" python3 cli.py \
            --model "$MODEL" \
            --auto_parallel True \
            --vad silero-vad-skip-gaps \
            --vad_max_merge_size 8.0 \
            --vad_merge_window 1.0 \
            --vad_padding 0.3 \
            --language "$LANGUAGE" \
            --whisper_implementation faster-whisper \
            --compute_type float16 \
            --output_dir "$MP4_DIR" \
            "$INPUT_FILE"
    else
        # 无GPU时去除compute_type参数
        HF_HUB_CACHE="$CACHE_DIR" python3 cli.py \
            --model "$MODEL" \
            --auto_parallel True \
            --vad silero-vad-skip-gaps \
            --vad_max_merge_size 8.0 \
            --vad_merge_window 1.0 \
            --vad_padding 0.3 \
            --language "$LANGUAGE" \
            --whisper_implementation faster-whisper \
            --output_dir "$MP4_DIR" \
            "$INPUT_FILE"
    fi
else
    log_info "使用 whisper 引擎..."
    if [ "$HAS_GPU" = true ]; then
        # 有GPU时使用fp16 True
        python3 cli.py \
            --model "$MODEL" \
            --auto_parallel True \
            --model_dir "$CACHE_DIR" \
            --vad silero-vad-skip-gaps \
            --vad_max_merge_size 8.0 \
            --vad_merge_window 1.0 \
            --vad_padding 0.3 \
            --language "$LANGUAGE" \
            --fp16 True \
            --output_dir "$MP4_DIR" \
            "$INPUT_FILE"
    else
        # 无GPU时使用fp16 False
        python3 cli.py \
            --model "$MODEL" \
            --auto_parallel True \
            --model_dir "$CACHE_DIR" \
            --vad silero-vad-skip-gaps \
            --vad_max_merge_size 8.0 \
            --vad_merge_window 1.0 \
            --vad_padding 0.3 \
            --language "$LANGUAGE" \
            --fp16 False \
            --output_dir "$MP4_DIR" \
            "$INPUT_FILE"
    fi
fi

log_info "字幕识别完成！"

# 清理工作将由trap自动执行