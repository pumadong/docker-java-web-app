#!/bin/bash

# ApplicationStart 钩子脚本
# 启动新的 Docker 容器

set -e

echo "=========================================="
echo "开始 ApplicationStart 阶段..."
echo "=========================================="

# 从 AWS Systems Manager Parameter Store 读取 Docker 用户名
# 与 buildspec.yml 中的配置保持一致
DOCKER_REGISTRY_USERNAME=$(aws ssm get-parameter --name /myapp/docker-credentials/username --with-decryption --query 'Parameter.Value' --output text)

# 从环境变量获取其他配置信息
DOCKER_REGISTRY_HOST="${DOCKER_REGISTRY_HOST:-docker.io}"
DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-docker-java-web-app}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-myapp-java-web-app}"
APP_PORT="${APP_PORT:-8080}"
HOST_PORT="${HOST_PORT:-8080}"

# 构建完整的镜像名称（与 buildspec.yml 中的格式保持一致）
FULL_IMAGE_NAME="${DOCKER_REGISTRY_HOST}/${DOCKER_REGISTRY_USERNAME}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

APP_DIR="/opt/myapp"

# 方法1: 如果使用 docker-compose.yml
if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo "检测到 docker-compose.yml，使用 Docker Compose 启动服务..."
    cd "$APP_DIR"
    
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d
    elif docker compose version &> /dev/null; then
        sudo docker compose up -d
    else
        echo "错误: Docker Compose 不可用"
        exit 1
    fi
    
    echo "使用 Docker Compose 启动完成"
else
    # 方法2: 直接使用 docker run 启动容器
    echo "使用 Docker run 启动容器..."
    echo "镜像: $FULL_IMAGE_NAME"
    echo "容器名称: $CONTAINER_NAME"
    echo "端口映射: $HOST_PORT:$APP_PORT"
    
    # 检查镜像是否存在
    if ! sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${FULL_IMAGE_NAME}$"; then
        echo "错误: 镜像 $FULL_IMAGE_NAME 不存在，请先运行 AfterInstall 脚本拉取镜像"
        exit 1
    fi
    
    # 启动容器
    # 可以根据实际需求添加更多参数，如环境变量、卷挂载等
    sudo docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${HOST_PORT}:${APP_PORT}" \
        "$FULL_IMAGE_NAME"
    
    echo "容器启动命令执行完成"
fi

# 等待几秒让容器完全启动
echo "等待容器启动..."
sleep 5

# 显示容器状态
echo "容器状态:"
sudo docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 显示容器日志（最近几行）
echo ""
echo "容器日志（最近10行）:"
sudo docker logs --tail 10 "$CONTAINER_NAME" 2>&1 || true

echo "ApplicationStart 阶段完成！"
echo "=========================================="

