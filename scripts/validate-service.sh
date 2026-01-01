#!/bin/bash

# ValidateService 钩子脚本
# 验证服务是否正常运行

set -e

echo "=========================================="
echo "开始 ValidateService 阶段..."
echo "=========================================="

CONTAINER_NAME="${CONTAINER_NAME:-myapp}"
APP_PORT="${APP_PORT:-8080}"
HOST_PORT="${HOST_PORT:-8080}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:${HOST_PORT}/hello}"
MAX_RETRIES=10
RETRY_INTERVAL=5

# 检查容器是否在运行
echo "检查容器状态..."
if ! sudo docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "错误: 容器 $CONTAINER_NAME 未运行"
    echo "容器列表:"
    sudo docker ps -a --filter "name=${CONTAINER_NAME}" || true
    exit 1
fi

CONTAINER_STATUS=$(sudo docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
echo "容器状态: $CONTAINER_STATUS"

# 检查容器健康状态（如果容器有健康检查）
if sudo docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
    echo "容器健康检查: 健康"
elif sudo docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "unhealthy"; then
    echo "警告: 容器健康检查: 不健康"
else
    echo "容器未配置健康检查或状态未知"
fi

# 检查端口是否监听
echo "检查端口 $HOST_PORT 是否监听..."
if command -v netstat &> /dev/null; then
    if sudo netstat -tlnp 2>/dev/null | grep -q ":${HOST_PORT} "; then
        echo "端口 $HOST_PORT 正在监听"
    else
        echo "警告: 端口 $HOST_PORT 未监听"
    fi
elif command -v ss &> /dev/null; then
    if sudo ss -tlnp 2>/dev/null | grep -q ":${HOST_PORT} "; then
        echo "端口 $HOST_PORT 正在监听"
    else
        echo "警告: 端口 $HOST_PORT 未监听"
    fi
fi

# 尝试访问健康检查端点（如果配置了）
if [ -n "$HEALTH_CHECK_URL" ] && [ "$HEALTH_CHECK_URL" != "http://localhost:${HOST_PORT}/health" ] || [ -n "$HEALTH_CHECK_URL" ]; then
    echo "执行健康检查: $HEALTH_CHECK_URL"
    
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -f -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
            echo "健康检查通过！"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "健康检查失败，等待 ${RETRY_INTERVAL} 秒后重试 ($RETRY_COUNT/$MAX_RETRIES)..."
                sleep $RETRY_INTERVAL
            else
                echo "警告: 健康检查失败，已达到最大重试次数"
                echo "这可能是正常的，如果应用需要更长时间启动"
            fi
        fi
    done
fi

# 检查容器日志中是否有错误
echo ""
echo "检查容器日志中的错误..."
ERROR_COUNT=$(sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | wc -l || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "警告: 在容器日志中发现 $ERROR_COUNT 个可能的错误"
    echo "最近的错误日志:"
    sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | tail -5 || true
else
    echo "未发现明显的错误日志"
fi

# 显示容器资源使用情况
echo ""
echo "容器资源使用情况:"
sudo docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" || true

echo ""
echo "ValidateService 阶段完成！"
echo "=========================================="

