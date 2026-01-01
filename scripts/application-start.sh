#!/bin/bash

# ApplicationStart 钩子脚本
# 启动新的 Docker 容器

set -e

# 设置日志文件路径
LOG_DIR="/opt/myapp/logs"
LOG_FILE="${LOG_DIR}/application-start-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# 函数：同时输出到控制台和日志文件
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "=========================================="
log "开始 ApplicationStart 阶段..."
log "日志文件: $LOG_FILE"
log "=========================================="

# 从 AWS Systems Manager Parameter Store 读取 Docker 用户名
# 与 buildspec.yml 中的配置保持一致
log "从 AWS Systems Manager Parameter Store 读取 Docker 用户名..."
DOCKER_REGISTRY_USERNAME=$(aws ssm get-parameter --name /myapp/docker-credentials/username --with-decryption --query 'Parameter.Value' --output text 2>&1 | tee -a "$LOG_FILE" || exit 1)

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
    log "检测到 docker-compose.yml，使用 Docker Compose 启动服务..."
    cd "$APP_DIR"
    
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d 2>&1 | tee -a "$LOG_FILE"
    elif docker compose version &> /dev/null; then
        sudo docker compose up -d 2>&1 | tee -a "$LOG_FILE"
    else
        log "错误: Docker Compose 不可用"
        exit 1
    fi
    
    log "使用 Docker Compose 启动完成"
else
    # 方法2: 直接使用 docker run 启动容器
    log "使用 Docker run 启动容器..."
    log "镜像: $FULL_IMAGE_NAME"
    log "容器名称: $CONTAINER_NAME"
    log "端口映射: $HOST_PORT:$APP_PORT"
    
    # 检查镜像是否存在
    # Docker 存储 docker.io 镜像时可能不包含 docker.io/ 前缀，所以需要检查两种格式
    IMAGE_NAME_WITHOUT_REGISTRY="${FULL_IMAGE_NAME#docker.io/}"
    if ! sudo docker image inspect "$FULL_IMAGE_NAME" >/dev/null 2>&1 && \
       ! sudo docker image inspect "$IMAGE_NAME_WITHOUT_REGISTRY" >/dev/null 2>&1; then
        log "错误: 镜像 $FULL_IMAGE_NAME 或 $IMAGE_NAME_WITHOUT_REGISTRY 不存在，请先运行 AfterInstall 脚本拉取镜像"
        exit 1
    fi
    
    # 确定实际使用的镜像名称（优先使用不带 docker.io/ 的版本，因为这是 Docker 存储的格式）
    if sudo docker image inspect "$IMAGE_NAME_WITHOUT_REGISTRY" >/dev/null 2>&1; then
        ACTUAL_IMAGE_NAME="$IMAGE_NAME_WITHOUT_REGISTRY"
    else
        ACTUAL_IMAGE_NAME="$FULL_IMAGE_NAME"
    fi
    log "使用镜像: $ACTUAL_IMAGE_NAME"
    
    # 启动容器
    # 可以根据实际需求添加更多参数，如环境变量、卷挂载等
    sudo docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${HOST_PORT}:${APP_PORT}" \
        "$ACTUAL_IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    log "容器启动命令执行完成"
fi

# 等待几秒让容器完全启动
log "等待容器启动..."
sleep 5

# 显示容器状态
log "容器状态:"
sudo docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"

# 显示容器日志（最近几行）
log ""
log "容器日志（最近10行）:"
sudo docker logs --tail 10 "$CONTAINER_NAME" 2>&1 | tee -a "$LOG_FILE" || true

log "ApplicationStart 阶段完成！"
log "详细日志已保存到: $LOG_FILE"
log "=========================================="

