#!/bin/bash

# AfterInstall 钩子脚本
# 在安装之后执行，拉取最新的 Docker 镜像

set -e

# 设置日志文件路径
LOG_DIR="/opt/myapp/logs"
LOG_FILE="${LOG_DIR}/after-install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# 函数：同时输出到控制台和日志文件
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "=========================================="
log "开始 AfterInstall 阶段..."
log "日志文件: $LOG_FILE"
log "=========================================="

# 检查并安装 AWS CLI（如果未安装）
if ! command -v aws &> /dev/null; then
    log "AWS CLI 未安装，开始安装..."
    
    # 检测操作系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log "无法检测操作系统类型"
        exit 1
    fi
    
    # 根据操作系统安装 AWS CLI
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        log "检测到 Ubuntu/Debian 系统，安装 AWS CLI..."
        # 使用 apt 安装（如果可用）
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y awscli 2>&1 | tee -a "$LOG_FILE"
        else
            # 或者使用官方安装脚本
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" 2>&1 | tee -a "$LOG_FILE"
            unzip -q /tmp/awscliv2.zip -d /tmp
            sudo /tmp/aws/install 2>&1 | tee -a "$LOG_FILE"
            rm -rf /tmp/aws /tmp/awscliv2.zip
        fi
    elif [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
        log "检测到 Amazon Linux/RHEL/CentOS 系统，安装 AWS CLI..."
        # Amazon Linux 2 通常已经有 AWS CLI v1，尝试安装 v2
        if command -v yum &> /dev/null; then
            # 检查是否已有 awscli
            if ! yum list installed awscli &> /dev/null; then
                sudo yum install -y awscli 2>&1 | tee -a "$LOG_FILE"
            else
                # 如果已有 v1，安装 v2
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" 2>&1 | tee -a "$LOG_FILE"
                unzip -q /tmp/awscliv2.zip -d /tmp 2>&1 | tee -a "$LOG_FILE"
                sudo /tmp/aws/install --update 2>&1 | tee -a "$LOG_FILE"
                rm -rf /tmp/aws /tmp/awscliv2.zip
            fi
        fi
    else
        # 尝试使用官方安装脚本（适用于大多数 Linux 系统）
        log "使用通用方法安装 AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" 2>&1 | tee -a "$LOG_FILE"
        unzip -q /tmp/awscliv2.zip -d /tmp 2>&1 | tee -a "$LOG_FILE"
        sudo /tmp/aws/install 2>&1 | tee -a "$LOG_FILE"
        rm -rf /tmp/aws /tmp/awscliv2.zip
    fi
    
    # 验证安装
    if command -v aws &> /dev/null; then
        log "AWS CLI 安装成功: $(aws --version 2>&1)"
    else
        log "错误: AWS CLI 安装失败"
        exit 1
    fi
else
    log "AWS CLI 已安装: $(aws --version 2>&1)"
fi

# 从 AWS Systems Manager Parameter Store 读取 Docker 凭据
# 与 buildspec.yml 中的配置保持一致
log "从 AWS Systems Manager Parameter Store 读取 Docker 凭据..."
DOCKER_REGISTRY_USERNAME=$(aws ssm get-parameter --name /myapp/docker-credentials/username --with-decryption --query 'Parameter.Value' --output text 2>&1)
if [ $? -ne 0 ]; then
    log "错误: 无法从 Parameter Store 读取用户名"
    log "AWS CLI 错误输出: $DOCKER_REGISTRY_USERNAME"
    exit 1
fi
log "成功读取 Docker Registry 用户名"

DOCKER_REGISTRY_PASSWORD=$(aws ssm get-parameter --name /myapp/docker-credentials/password --with-decryption --query 'Parameter.Value' --output text 2>&1)
if [ $? -ne 0 ]; then
    log "错误: 无法从 Parameter Store 读取密码"
    log "AWS CLI 错误输出: $DOCKER_REGISTRY_PASSWORD"
    exit 1
fi
log "成功读取 Docker Registry 密码"

# 从环境变量获取其他 Docker 镜像信息
DOCKER_REGISTRY_HOST="${DOCKER_REGISTRY_HOST:-docker.io}"
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-docker-java-web-app}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"

# 构建完整的镜像名称（与 buildspec.yml 中的格式保持一致）
FULL_IMAGE_NAME="${DOCKER_REGISTRY_HOST}/${DOCKER_REGISTRY_USERNAME}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

log "准备拉取 Docker 镜像: $FULL_IMAGE_NAME"

# 登录到 Docker Registry
log "登录到 Docker Registry: $DOCKER_REGISTRY_HOST"
echo "$DOCKER_REGISTRY_PASSWORD" | sudo docker login \
    --username "$DOCKER_REGISTRY_USERNAME" \
    --password-stdin \
    "$DOCKER_REGISTRY_HOST" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "错误: Docker Registry 登录失败"
    exit 1
fi
log "Docker Registry 登录成功"

# 拉取 Docker 镜像
log "正在拉取 Docker 镜像..."
if sudo docker pull "$FULL_IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"; then
    log "Docker 镜像拉取成功: $FULL_IMAGE_NAME"
    
    # 显示镜像信息
    log "镜像信息:"
    sudo docker images "$FULL_IMAGE_NAME" | head -2 | tee -a "$LOG_FILE"
else
    log "错误: Docker 镜像拉取失败"
    exit 1
fi

# 清理旧的未使用的镜像（可选，节省空间）
log "清理未使用的 Docker 镜像..."
sudo docker image prune -f 2>&1 | tee -a "$LOG_FILE" || true

log "AfterInstall 阶段完成！"
log "详细日志已保存到: $LOG_FILE"
log "=========================================="

