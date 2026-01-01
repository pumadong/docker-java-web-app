#!/bin/bash

# BeforeInstall 钩子脚本
# 在安装之前执行，确保 Docker 环境已准备好

set -e

# 设置日志文件路径
LOG_DIR="/opt/myapp/logs"
LOG_FILE="${LOG_DIR}/before-install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# 函数：同时输出到控制台和日志文件
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "=========================================="
log "开始 BeforeInstall 阶段..."
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
        sudo apt-get update -qq
        sudo apt-get install -y unzip 2>&1 | tee -a "$LOG_FILE" || true
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" 2>&1 | tee -a "$LOG_FILE"
        unzip -q /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install 2>&1 | tee -a "$LOG_FILE"
        rm -rf /tmp/aws /tmp/awscliv2.zip
    elif [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
        log "检测到 Amazon Linux/RHEL/CentOS 系统，安装 AWS CLI..."
        if command -v yum &> /dev/null; then
            sudo yum install -y unzip 2>&1 | tee -a "$LOG_FILE" || true
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" 2>&1 | tee -a "$LOG_FILE"
            unzip -q /tmp/awscliv2.zip -d /tmp 2>&1 | tee -a "$LOG_FILE"
            sudo /tmp/aws/install --update 2>&1 | tee -a "$LOG_FILE"
            rm -rf /tmp/aws /tmp/awscliv2.zip
        fi
    else
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

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    log "Docker 未安装，开始安装 Docker..."
    
    # 检测操作系统类型（如果之前未定义，重新检测）
    if [ -z "$OS" ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            log "无法检测操作系统类型"
            exit 1
        fi
    fi
    
    # 根据操作系统安装 Docker
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        log "检测到 Ubuntu/Debian 系统，安装 Docker..."
        sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release 2>&1 | tee -a "$LOG_FILE"
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1 | tee -a "$LOG_FILE"
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>&1 | tee -a "$LOG_FILE"
    elif [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
        log "检测到 Amazon Linux/RHEL/CentOS 系统，安装 Docker..."
        sudo yum update -y 2>&1 | tee -a "$LOG_FILE"
        sudo yum install -y docker 2>&1 | tee -a "$LOG_FILE"
        sudo systemctl start docker 2>&1 | tee -a "$LOG_FILE"
        sudo systemctl enable docker 2>&1 | tee -a "$LOG_FILE"
    else
        log "不支持的操作系统: $OS"
        exit 1
    fi
else
    log "Docker 已安装: $(docker --version 2>&1)"
fi

# 确保 Docker 服务正在运行
if ! sudo systemctl is-active --quiet docker; then
    log "启动 Docker 服务..."
    sudo systemctl start docker 2>&1 | tee -a "$LOG_FILE"
    sudo systemctl enable docker 2>&1 | tee -a "$LOG_FILE"
fi

# 检查 Docker Compose 是否可用（可选）
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    log "Docker Compose 可用"
else
    log "警告: Docker Compose 未安装（可选）"
fi

# 创建应用目录（如果不存在）
APP_DIR="/opt/myapp"
if [ ! -d "$APP_DIR" ]; then
    log "创建应用目录: $APP_DIR"
    sudo mkdir -p "$APP_DIR"
    sudo chown -R $USER:$USER "$APP_DIR" 2>/dev/null || true
fi

log "BeforeInstall 阶段完成！"
log "详细日志已保存到: $LOG_FILE"
log "=========================================="

