#!/bin/bash

# ApplicationStop 钩子脚本
# 停止当前运行的 Docker 容器

set -e

echo "=========================================="
echo "开始 ApplicationStop 阶段..."
echo "=========================================="

# 从环境变量获取容器名称
CONTAINER_NAME="${CONTAINER_NAME:-myapp-java-web-app}"
APP_DIR="/opt/myapp"

# 方法1: 如果使用 docker-compose.yml
if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo "检测到 docker-compose.yml，使用 Docker Compose 停止服务..."
    cd "$APP_DIR"
    
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose down || true
    elif docker compose version &> /dev/null; then
        sudo docker compose down || true
    else
        echo "警告: Docker Compose 不可用，尝试直接停止容器..."
    fi
fi

# 方法2: 直接停止指定名称的容器
if sudo docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "停止容器: $CONTAINER_NAME"
    sudo docker stop "$CONTAINER_NAME" || true
    echo "删除容器: $CONTAINER_NAME"
    sudo docker rm "$CONTAINER_NAME" || true
else
    echo "容器 $CONTAINER_NAME 不存在或已停止"
fi

# 方法3: 停止所有运行中的应用容器（根据标签或名称模式）
# 可以根据实际情况调整过滤条件
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" || true)
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "停止所有匹配的容器..."
    echo "$RUNNING_CONTAINERS" | while read container; do
        if [ -n "$container" ]; then
            echo "停止容器: $container"
            sudo docker stop "$container" || true
            sudo docker rm "$container" || true
        fi
    done
fi

# 显示当前运行的容器状态
echo "当前运行的容器:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true

echo "ApplicationStop 阶段完成！"
echo "=========================================="

