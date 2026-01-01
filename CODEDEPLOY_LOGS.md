# AWS CodeDeploy 日志查看指南

## ⚠️ 重要说明

**AWS CodeDeploy 控制台的限制：**
- AWS CodeDeploy 控制台通常**只显示错误日志**
- 如果部署阶段**没有报错，控制台不会显示详细的执行日志**
- 所有详细的日志（包括成功的步骤）都保存在服务器上的日志文件中

**因此，要查看完整的部署日志，您需要：**
1. **SSH 登录到 EC2 实例**（推荐方法）
2. 查看日志文件：`/opt/myapp/logs/`
3. 或者查看 CodeDeploy Agent 的日志文件

---

## 日志位置

### 1. 部署脚本日志（推荐 ⭐）

**这是查看完整部署日志的最佳方式！**

所有部署脚本的日志都会自动保存到：
```
/opt/myapp/logs/
```

各阶段的日志文件（每个部署都会创建新的日志文件）：
- `validate-service-YYYYMMDD-HHMMSS.log` - 服务验证日志
- `application-start-YYYYMMDD-HHMMSS.log` - 应用启动日志
- `application-stop-YYYYMMDD-HHMMSS.log` - 应用停止日志
- `after-install-YYYYMMDD-HHMMSS.log` - 安装后日志
- `before-install-YYYYMMDD-HHMMSS.log` - 安装前日志

**在 EC2 实例上查看日志（SSH 登录后执行）：**

```bash
# 1. 查看最新的验证服务日志（最重要，查看部署是否成功）
sudo tail -100 $(sudo ls -t /opt/myapp/logs/validate-service-*.log 2>/dev/null | head -1)

# 2. 查看最新的应用启动日志
sudo tail -100 $(sudo ls -t /opt/myapp/logs/application-start-*.log 2>/dev/null | head -1)

# 3. 查看所有日志文件（按时间排序，最新的在前）
sudo ls -lth /opt/myapp/logs/

# 4. 实时查看最新的日志文件
sudo tail -f $(sudo ls -t /opt/myapp/logs/*.log 2>/dev/null | head -1)

# 5. 查看特定阶段的日志（例如：after-install）
sudo ls -lt /opt/myapp/logs/after-install-*.log | head -1 | awk '{print $NF}' | xargs sudo tail -100

# 6. 查看所有日志文件的内容（最近 10 个文件）
for log in $(sudo ls -t /opt/myapp/logs/*.log 2>/dev/null | head -10); do
    echo "========== $log =========="
    sudo tail -50 "$log"
    echo ""
done
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

### 3. CodeDeploy 部署脚本输出（CodeDeploy Agent 保存的日志）

CodeDeploy Agent 会将脚本的标准输出和错误输出保存到：
```
/opt/codedeploy-agent/deployment-root/[DEPLOYMENT_GROUP_ID]/d-[DEPLOYMENT_ID]/logs/scripts.log
```

**注意：** 这个日志文件包含了所有脚本的 stdout 输出，但可能没有我们自定义的日志文件详细。

**在 EC2 实例上查找部署日志：**
```bash
# 查看最新的部署日志（所有脚本的输出）
sudo find /opt/codedeploy-agent/deployment-root -name "scripts.log" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $NF}' | xargs sudo tail -200

# 列出所有部署目录
sudo ls -lt /opt/codedeploy-agent/deployment-root/*/d-*/logs/scripts.log 2>/dev/null

# 查看特定部署组的日志（需要替换 DEPLOYMENT_GROUP_ID）
# 首先找到部署组 ID
sudo ls /opt/codedeploy-agent/deployment-root/
# 然后查看日志
sudo cat /opt/codedeploy-agent/deployment-root/[DEPLOYMENT_GROUP_ID]/d-*/logs/scripts.log
```

### 4. CloudWatch Logs（如果配置了）

如果 CodeDeploy 配置了 CloudWatch Logs 集成，可以在 AWS 控制台查看：
- AWS Console → CloudWatch → Log groups
- 查找名称类似 `/aws/codedeploy/[APPLICATION_NAME]` 的日志组

**注意：** 默认情况下，CodeDeploy 不会自动将日志发送到 CloudWatch。需要额外配置。

---

## 🎯 快速查看日志的方法（推荐）

### 方法 1：SSH 登录到 EC2 实例（最简单）

```bash
# SSH 登录到您的 EC2 实例
ssh -i your-key.pem ec2-user@your-ec2-ip

# 查看最新的验证服务日志（部署是否成功）
sudo tail -100 $(sudo ls -t /opt/myapp/logs/validate-service-*.log 2>/dev/null | head -1)

# 查看所有阶段的日志文件列表
sudo ls -lth /opt/myapp/logs/
```

### 方法 2：使用 AWS Systems Manager Session Manager（无需 SSH 密钥）

如果您的 EC2 实例已安装 SSM Agent，可以使用 AWS Systems Manager Session Manager：

1. 在 AWS 控制台：**EC2 → Instances → 选择实例 → Connect → Session Manager**
2. 或者使用 AWS CLI：
   ```bash
   aws ssm start-session --target i-xxxxxxxxxxxxx
   ```
3. 然后在会话中执行上面的日志查看命令

### 方法 3：使用 AWS Systems Manager Run Command（批量查看）

```bash
# 在本地执行，查看远程实例的日志
aws ssm send-command \
    --instance-ids i-xxxxxxxxxxxxx \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo tail -100 $(sudo ls -t /opt/myapp/logs/validate-service-*.log 2>/dev/null | head -1)"]' \
    --output text

# 获取命令执行结果
aws ssm get-command-invocation \
    --command-id "命令ID" \
    --instance-id i-xxxxxxxxxxxxx \
    --query "StandardOutputContent" \
    --output text
```

---

## 为什么 AWS 控制台看不到日志？

**原因：**
1. AWS CodeDeploy 控制台**主要显示部署状态**（成功/失败）
2. 只有在**脚本执行失败**时，控制台才会显示错误信息
3. 如果脚本**执行成功**，控制台通常只显示 "Succeeded"，不显示详细日志

**解决方案：**
- ✅ **使用日志文件**：所有详细日志都保存在 `/opt/myapp/logs/` 目录
- ✅ **SSH 登录服务器**：直接查看日志文件（推荐）
- ✅ **使用 Systems Manager**：通过 AWS 控制台连接到实例查看日志
- ⚠️ **CodeDeploy Agent 日志**：在 `/opt/codedeploy-agent/deployment-root/.../logs/scripts.log`，包含所有脚本的输出

---

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

