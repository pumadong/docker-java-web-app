#!/bin/bash

# ValidateService 钩子脚本
# 验证服务是否正常运行

set -e

# 设置日志文件路径
LOG_DIR="/opt/myapp/logs"
LOG_FILE="${LOG_DIR}/validate-service-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# 函数：同时输出到控制台和日志文件
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "=========================================="
log "开始 ValidateService 阶段..."
log "日志文件: $LOG_FILE"
log "=========================================="

CONTAINER_NAME="${CONTAINER_NAME:-myapp-java-web-app}"
APP_PORT="${APP_PORT:-8080}"
HOST_PORT="${HOST_PORT:-8080}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:${HOST_PORT}/hello}"
MAX_RETRIES=10
RETRY_INTERVAL=5
HEALTH_CHECK_PASSED=false

# 检查容器是否在运行
log "检查容器状态..."
if ! sudo docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    log "错误: 容器 $CONTAINER_NAME 未运行"
    log "容器列表:"
    sudo docker ps -a --filter "name=${CONTAINER_NAME}" | tee -a "$LOG_FILE" || true
    exit 1
fi

CONTAINER_STATUS=$(sudo docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
log "容器状态: $CONTAINER_STATUS"

# 检查容器健康状态（如果容器有健康检查）
if sudo docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
    log "容器健康检查: 健康"
elif sudo docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "unhealthy"; then
    log "警告: 容器健康检查: 不健康"
else
    log "容器未配置健康检查或状态未知"
fi

# 检查端口是否监听
log "检查端口 $HOST_PORT 是否监听..."
if command -v netstat &> /dev/null; then
    if sudo netstat -tlnp 2>/dev/null | grep -q ":${HOST_PORT} "; then
        log "端口 $HOST_PORT 正在监听"
    else
        log "警告: 端口 $HOST_PORT 未监听"
    fi
elif command -v ss &> /dev/null; then
    if sudo ss -tlnp 2>/dev/null | grep -q ":${HOST_PORT} "; then
        log "端口 $HOST_PORT 正在监听"
    else
        log "警告: 端口 $HOST_PORT 未监听"
    fi
fi

# 尝试访问健康检查端点（如果配置了）
if [ -n "$HEALTH_CHECK_URL" ]; then
    # 检查 curl 是否可用
    if ! command -v curl &> /dev/null; then
        log "错误: curl 命令不可用，无法执行健康检查"
        exit 1
    fi
    
    log "执行健康检查: $HEALTH_CHECK_URL"
    
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>&1 || echo "000")
        CURL_ERROR=$?
        
        if [ "$HTTP_CODE" = "200" ] && [ $CURL_ERROR -eq 0 ]; then
            log "健康检查通过！HTTP 状态码: $HTTP_CODE"
            HEALTH_CHECK_PASSED=true
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                log "健康检查失败 (HTTP $HTTP_CODE, curl错误码: $CURL_ERROR)，等待 ${RETRY_INTERVAL} 秒后重试 ($RETRY_COUNT/$MAX_RETRIES)..."
                sleep $RETRY_INTERVAL
            else
                log "错误: 健康检查失败，已达到最大重试次数 ($MAX_RETRIES)"
                log "健康检查 URL: $HEALTH_CHECK_URL"
                log "最后一次 HTTP 状态码: $HTTP_CODE"
                log "curl 错误码: $CURL_ERROR"
                HEALTH_CHECK_PASSED=false
            fi
        fi
    done
    
    # 如果健康检查失败，退出并返回错误代码
    if [ "$HEALTH_CHECK_PASSED" = false ]; then
        log "部署验证失败: 健康检查未通过"
        log "详细日志已保存到: $LOG_FILE"
        exit 1
    fi
fi

# 检查容器日志中是否有错误
log ""
log "检查容器日志中的错误..."
ERROR_COUNT=$(sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | wc -l || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    log "警告: 在容器日志中发现 $ERROR_COUNT 个可能的错误"
    log "最近的错误日志:"
    sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | tail -5 | tee -a "$LOG_FILE" || true
else
    log "未发现明显的错误日志"
fi

# 显示容器资源使用情况
log ""
log "容器资源使用情况:"
sudo docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | tee -a "$LOG_FILE" || true

log ""
log "ValidateService 阶段完成！"
log "详细日志已保存到: $LOG_FILE"
log "=========================================="

