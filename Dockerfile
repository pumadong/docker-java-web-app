# --- 第一阶段：构建阶段 ---
FROM maven:3.8.6-jdk-8-slim AS build

# 设置工作目录
WORKDIR /app

# 1. 优化缓存：先拷贝 pom.xml 并下载依赖
# 这样只要 pom.xml 没变，后续构建就可以跳过依赖下载步骤
COPY pom.xml .
RUN mvn dependency:go-offline

# 2. 拷贝源代码并打包
COPY src ./src
RUN mvn clean package -DskipTests

# --- 第二阶段：运行阶段 ---
# FROM eclipse-temurin:8-jre-alpine
FROM gcr.io/distroless/java:8

# 设置工作目录
WORKDIR /app

# 从构建阶段拷贝生成的 jar 包到当前镜像
# 请根据你 pom.xml 中的 artifactId 和 version 修改 jar 包名称
COPY --from=build /app/target/*.jar docker-java-web-app-0.0.1-SNAPSHOT.jar

# 暴露项目端口（假设为 8080）
# EXPOSE 并不实际开放端口，它更像是一种文档说明，告诉开发者或系统该应用预期监听哪个端口
EXPOSE 8080

# 启动命令
ENTRYPOINT ["java", "-jar", "docker-java-web-app-0.0.1-SNAPSHOT.jar"]