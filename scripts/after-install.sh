#!/bin/bash

# AfterInstall 钩子脚本
# 在安装之后执行，拉取最新的 Docker 镜像

set -e

echo "=========================================="
echo "开始 AfterInstall 阶段..."
echo "=========================================="

# 从 AWS Systems Manager Parameter Store 读取 Docker 凭据
# 与 buildspec.yml 中的配置保持一致
echo "从 AWS Systems Manager Parameter Store 读取 Docker 凭据..."
DOCKER_REGISTRY_USERNAME=$(aws ssm get-parameter --name /myapp/docker-credentials/username --with-decryption --query 'Parameter.Value' --output text)
DOCKER_REGISTRY_PASSWORD=$(aws ssm get-parameter --name /myapp/docker-credentials/password --with-decryption --query 'Parameter.Value' --output text)

# 从环境变量获取其他 Docker 镜像信息
DOCKER_REGISTRY_HOST="${DOCKER_REGISTRY_HOST:-docker.io}"
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-docker-java-web-app}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"

# 构建完整的镜像名称（与 buildspec.yml 中的格式保持一致）
FULL_IMAGE_NAME="${DOCKER_REGISTRY_HOST}/${DOCKER_REGISTRY_USERNAME}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

echo "准备拉取 Docker 镜像: $FULL_IMAGE_NAME"

# 登录到 Docker Registry
echo "登录到 Docker Registry: $DOCKER_REGISTRY_HOST"
echo "$DOCKER_REGISTRY_PASSWORD" | sudo docker login \
    --username "$DOCKER_REGISTRY_USERNAME" \
    --password-stdin \
    "$DOCKER_REGISTRY_HOST"

# 拉取 Docker 镜像
echo "正在拉取 Docker 镜像..."
if sudo docker pull "$FULL_IMAGE_NAME"; then
    echo "Docker 镜像拉取成功: $FULL_IMAGE_NAME"
    
    # 显示镜像信息
    echo "镜像信息:"
    sudo docker images "$FULL_IMAGE_NAME" | head -2
else
    echo "错误: Docker 镜像拉取失败"
    exit 1
fi

# 清理旧的未使用的镜像（可选，节省空间）
echo "清理未使用的 Docker 镜像..."
sudo docker image prune -f || true

echo "AfterInstall 阶段完成！"
echo "=========================================="

