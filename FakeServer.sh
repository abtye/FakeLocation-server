#!/bin/bash
# FakeLocation-server 一键部署脚本
# 兼容：Ubuntu/Debian/CentOS 7+/8+
set -e # 任意步骤出错则终止脚本

# 颜色输出函数（增强可读性）
green_echo() { echo -e "\033[32m$1\033[0m"; }
red_echo() { echo -e "\033[31m$1\033[0m"; }
blue_echo() { echo -e "\033[34m$1\033[0m"; }

# 第一步：识别系统发行版
blue_echo "===== 1. 识别系统发行版 ====="
if [ -f /etc/redhat-release ]; then
    SYS_TYPE="centos"
    PKG_MANAGER="yum"
    # CentOS8+ 自动切换为dnf（兼容yum命令）
    if grep -q "CentOS Linux release 8" /etc/redhat-release || grep -q "CentOS Stream 8" /etc/redhat-release; then
        PKG_MANAGER="dnf"
    fi
elif [ -f /etc/os-release ]; then
    if grep -q "Ubuntu" /etc/os-release || grep -q "Debian" /etc/os-release; then
        SYS_TYPE="debian"
        PKG_MANAGER="apt"
    else
        red_echo "错误：不支持的系统，仅支持Ubuntu/Debian/CentOS！"
        exit 1
    fi
else
    red_echo "错误：无法识别系统发行版！"
    exit 1
fi
green_echo "识别成功：当前系统为${SYS_TYPE}，包管理器为${PKG_MANAGER}"

# 第二步：安装基础依赖（git/网络工具）
blue_echo -e "\n===== 2. 安装基础依赖（git/net-tools） ====="
if [ $SYS_TYPE = "centos" ]; then
    $PKG_MANAGER install -y git net-tools
else
    $PKG_MANAGER update -y && $PKG_MANAGER install -y git net-tools
fi
green_echo "基础依赖安装完成"

# 第三步：更新系统
blue_echo -e "\n===== 3. 系统基础更新 ====="
if [ $SYS_TYPE = "centos" ]; then
    $PKG_MANAGER update -y
else
    $PKG_MANAGER upgrade -y
fi
green_echo "系统更新完成"

# 第四步：安装Node.js + NPM
blue_echo -e "\n===== 4. 安装Node.js和NPM ====="
if [ $SYS_TYPE = "centos" ]; then
    $PKG_MANAGER install -y nodejs npm
else
    $PKG_MANAGER install -y nodejs npm
fi
# 验证安装
node -v && npm -v
green_echo "Node.js + NPM 安装完成"

# 第五步：克隆项目仓库
blue_echo -e "\n===== 5. 克隆FakeLocation-server仓库 ====="
GIT_URL="https://github.com/BobH233/FakeLocation-server.git"
if [ -d "FakeLocation-server" ]; then
    red_echo "检测到已有项目目录，先删除旧目录..."
    rm -rf FakeLocation-server
fi
git clone $GIT_URL
green_echo "仓库克隆完成"

# 第六步：进入项目目录并安装依赖
blue_echo -e "\n===== 6. 安装项目Node依赖 ====="
cd FakeLocation-server || { red_echo "进入项目目录失败！"; exit 1; }
npm install --registry=https://registry.npmmirror.com/ # 用国内镜像加速安装
green_echo "项目依赖安装完成"

# 第七步：检查8000端口是否被占用
blue_echo -e "\n===== 7. 检查8000端口占用情况 ====="
PORT=8000
PID=$(netstat -tulpn | grep ":$PORT" | awk '{print $7}' | cut -d/ -f1)
if [ -n "$PID" ]; then
    red_echo "错误：8000端口已被进程PID=$PID占用！"
    red_echo "请先停止该进程：kill -9 $PID，再重新运行脚本"
    exit 1
fi
green_echo "8000端口未被占用，可正常启动"

# 第八步：后台启动服务（nohup持久化）
blue_echo -e "\n===== 8. 后台启动FakeLocation-server ====="
nohup node index.js > nohup.out 2>&1 &
# 验证启动
sleep 3 # 给服务启动时间
NEW_PID=$(ps -ef | grep "node index.js" | grep -v grep | awk '{print $2}')
if [ -n "$NEW_PID" ]; then
    green_echo "====================================="
    green_echo "服务启动成功！进程PID：$NEW_PID"
    green_echo "日志文件：$(pwd)/nohup.out"
    green_echo "查看日志：tail -f nohup.out"
    green_echo "停止服务：kill -9 $NEW_PID"
    green_echo "====================================="
else
    red_echo "服务启动失败！请查看日志：cat nohup.out"
    exit 1
fi
