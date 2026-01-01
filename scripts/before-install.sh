#!/bin/bash

# BeforeInstall 钩子脚本
# 在安装之前执行，确保 Docker 环境已准备好

set -e

echo "=========================================="
echo "开始 BeforeInstall 阶段..."
echo "=========================================="

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，开始安装 Docker..."
    
    # 检测操作系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "无法检测操作系统类型"
        exit 1
    fi
    
    # 根据操作系统安装 Docker
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        echo "检测到 Ubuntu/Debian 系统，安装 Docker..."
        sudo apt-get update
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
        echo "检测到 Amazon Linux/RHEL/CentOS 系统，安装 Docker..."
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "不支持的操作系统: $OS"
        exit 1
    fi
else
    echo "Docker 已安装: $(docker --version)"
fi

# 确保 Docker 服务正在运行
if ! sudo systemctl is-active --quiet docker; then
    echo "启动 Docker 服务..."
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# 检查 Docker Compose 是否可用（可选）
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "Docker Compose 可用"
else
    echo "警告: Docker Compose 未安装（可选）"
fi

# 创建应用目录（如果不存在）
APP_DIR="/opt/myapp"
if [ ! -d "$APP_DIR" ]; then
    echo "创建应用目录: $APP_DIR"
    sudo mkdir -p "$APP_DIR"
    sudo chown -R $USER:$USER "$APP_DIR" 2>/dev/null || true
fi

echo "BeforeInstall 阶段完成！"
echo "=========================================="

