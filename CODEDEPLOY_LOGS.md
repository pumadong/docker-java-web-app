# AWS CodeDeploy 日志查看指南

## 日志位置

### 1. 部署脚本日志（推荐）

所有部署脚本的日志现在会自动保存到：
```
/opt/myapp/logs/
```

各阶段的日志文件：
- `validate-service-YYYYMMDD-HHMMSS.log` - 服务验证日志
- `application-start-YYYYMMDD-HHMMSS.log` - 应用启动日志
- `application-stop-YYYYMMDD-HHMMSS.log` - 应用停止日志
- `after-install-YYYYMMDD-HHMMSS.log` - 安装后日志
- `before-install-YYYYMMDD-HHMMSS.log` - 安装前日志

**查看最新日志：**
```bash
# 查看最新的验证服务日志
sudo tail -f /opt/myapp/logs/validate-service-*.log | tail -1

# 查看所有日志文件
sudo ls -lth /opt/myapp/logs/

# 查看特定部署的日志（按时间排序）
sudo ls -lt /opt/myapp/logs/ | head -10
```

### 2. CodeDeploy Agent 日志

CodeDeploy Agent 的主日志文件：
```
/var/log/aws/codedeploy-agent/codedeploy-agent.log
```

**查看 Agent 日志：**
```bash
# 查看最近的日志
sudo tail -100 /var/log/aws/codedeploy-agent/codedeploy-agent.log

# 实时查看日志
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

# 查看错误日志
sudo grep -i error /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -50
```

### 3. CodeDeploy 部署脚本输出

CodeDeploy 会将脚本的标准输出和错误输出保存到：
```
/opt/codedeploy-agent/deployment-root/[DEPLOYMENT_GROUP_ID]/d-[DEPLOYMENT_ID]/logs/
```

**查找部署日志：**
```bash
# 列出所有部署目录
sudo ls -lt /opt/codedeploy-agent/deployment-root/*/d-*/logs/scripts.log

# 查看最新的部署日志
sudo find /opt/codedeploy-agent/deployment-root -name "scripts.log" -type f -exec ls -lt {} + | head -1 | awk '{print $NF}' | xargs sudo tail -100

# 查看特定部署组的日志（替换 DEPLOYMENT_GROUP_ID）
sudo cat /opt/codedeploy-agent/deployment-root/[DEPLOYMENT_GROUP_ID]/d-*/logs/scripts.log
```

### 4. CloudWatch Logs（如果配置了）

如果 CodeDeploy 配置了 CloudWatch Logs 集成，可以在 AWS 控制台查看：
- AWS Console → CloudWatch → Log groups
- 查找名称类似 `/aws/codedeploy/[APPLICATION_NAME]` 的日志组

## 快速诊断命令

### 查看最近的部署失败原因

```bash
# 1. 查看最新的验证服务日志
sudo tail -100 $(sudo ls -t /opt/myapp/logs/validate-service-*.log 2>/dev/null | head -1)

# 2. 查看 CodeDeploy Agent 错误
sudo grep -i "error\|failed\|exception" /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -20

# 3. 查看容器状态
sudo docker ps -a
sudo docker logs myapp-java-web-app --tail 50

# 4. 检查服务是否响应
curl -v http://localhost:8080/hello

# 5. 查看系统日志
sudo journalctl -u codedeploy-agent -n 50 --no-pager
```

### 检查 CodeDeploy Agent 状态

```bash
# 检查 Agent 是否运行
sudo service codedeploy-agent status

# 查看 Agent 配置文件
sudo cat /etc/codedeploy-agent/conf/codedeploy.onpremises.yml

# 重启 Agent（如果需要）
sudo service codedeploy-agent restart
```

## 日志文件权限

如果遇到权限问题，可以使用：

```bash
# 确保日志目录可访问
sudo chmod -R 755 /opt/myapp/logs/
sudo chown -R $USER:$USER /opt/myapp/logs/ 2>/dev/null || true
```

## 清理旧日志

为了避免日志文件占用过多磁盘空间：

```bash
# 删除 7 天前的日志文件
sudo find /opt/myapp/logs/ -name "*.log" -mtime +7 -delete

# 或者只保留最近 10 个日志文件
sudo ls -t /opt/myapp/logs/*.log | tail -n +11 | xargs -r sudo rm
```

## 故障排查步骤

1. **检查部署是否启动**
   ```bash
   sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
   ```

2. **查看脚本执行日志**
   ```bash
   sudo ls -lt /opt/myapp/logs/
   sudo tail -100 $(sudo ls -t /opt/myapp/logs/*.log | head -1)
   ```

3. **检查容器状态**
   ```bash
   sudo docker ps -a
   sudo docker logs myapp-java-web-app
   ```

4. **验证服务健康**
   ```bash
   curl -v http://localhost:8080/hello
   ```

5. **查看系统资源**
   ```bash
   df -h
   free -h
   sudo docker stats --no-stream
   ```

