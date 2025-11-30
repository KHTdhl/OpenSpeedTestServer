#!/bin/sh
# OpenSpeedTest 安装器（适用于 GL.iNet 路由器上的 NGINX）
# 作者: phantasm22
# 许可证: GPL-3.0
# 版本: 2025-11-13
# 本脚本将所有用户提示与输出替换为中文（保留颜色、Emoji）

# -----------------------------
# 颜色 & Emoji
# -----------------------------
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"

SPLASH="
   _____ _          _ _   _      _   
  / ____| |        (_) \ | |    | |  
 | |  __| |  ______ _|  \| | ___| |_ 
 | | |_ | | |______| | . \` |/ _ \ __|
 | |__| | |____    | | |\  |  __/ |_ 
  \_____|______|   |_|_| \_|\___|\__|

         OpenSpeedTest for GL-iNet
"

# -----------------------------
# 全局变量
# -----------------------------
INSTALL_DIR="/www2"
CONFIG_PATH="/etc/nginx/nginx_openspeedtest.conf"
STARTUP_SCRIPT="/etc/init.d/nginx_speedtest"
REQUIRED_SPACE_MB=64
PORT=8888
PID_FILE="/var/run/nginx_OpenSpeedTest.pid"
BLA_BOX="┤ ┴ ├ ┬"  # 旋转帧
opkg_updated=0
SCRIPT_URL="https://raw.githubusercontent.com/phantasm22/OpenSpeedTestServer/refs/heads/main/install_openspeedtest.sh"
TMP_NEW_SCRIPT="/tmp/install_openspeedtest_new.sh"
SCRIPT_PATH="$0"
[ "${SCRIPT_PATH#*/}" != "$SCRIPT_PATH" ] || SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"

# -----------------------------
# 清理上一次更新（如果存在 .new）
# -----------------------------
case "$0" in
    *.new)
        ORIGINAL="${0%.new}"
        printf "🧹 应用更新中...
"
        mv -f "$0" "$ORIGINAL" && chmod +x "$ORIGINAL"
        printf "✅ 已应用更新。正在重启主脚本...
"
        sleep 1
        exec "$ORIGINAL" "$@"
        ;;
esac

# -----------------------------
# 工具函数
# -----------------------------
spinner() {
    pid=$1
    i=0
    task=$2
    while kill -0 "$pid" 2>/dev/null; do
        frame=$(printf "%s" "$BLA_BOX" | cut -d' ' -f$((i % 4 + 1)))
        printf "
⏳  %s... %-20s" "$task" "$frame"
        if command -v usleep >/dev/null 2>&1; then
            usleep 200000
        else
            sleep 1
        fi
        i=$((i+1))
    done
    printf "
✅  %s... 完成!%-20s
" "$task" " "
}

press_any_key() {
    printf "按任意键继续..."
    read -r _ </dev/tty
}

# -----------------------------
# 磁盘空间检查与外部驱动器处理
# -----------------------------
check_space() {
    SPACE_CHECK_PATH="$INSTALL_DIR"
    [ ! -e "$INSTALL_DIR" ] && SPACE_CHECK_PATH="/"

    AVAILABLE_SPACE_MB=$(df -m "$SPACE_CHECK_PATH" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$AVAILABLE_SPACE_MB" ] || [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
        printf "❌ 在 %s 可用空间不足。需要: %dMB，当前: %sMB
" "$SPACE_CHECK_PATH" "$REQUIRED_SPACE_MB" "${AVAILABLE_SPACE_MB:-0}"
        printf "
🔍 正在搜索已挂载的外部驱动器以寻找足够空间...
"

        for mountpoint in $(awk '$2 ~ /^\/mnt\// {print $2}' /proc/mounts); do
            ext_space=$(df -m "$mountpoint" | awk 'NR==2 {print $4}')
            if [ "$ext_space" -ge "$REQUIRED_SPACE_MB" ]; then
                printf "💾 找到外部磁盘，空间充足：%s（可用 %dMB）
" "$mountpoint" "$ext_space"
                printf "要通过在 %s 创建符号链接来使用此位置安装吗？[y/N]: " "$INSTALL_DIR"
                read -r use_external
                if [ "$use_external" = "y" ] || [ "$use_external" = "Y" ]; then
                    INSTALL_DIR="$mountpoint/openspeedtest"
                    mkdir -p "$INSTALL_DIR"
                    ln -sf "$INSTALL_DIR" /www2
                    printf "✅ 已创建符号链接：/www2 -> %s
" "$INSTALL_DIR"
                    break
                fi
            fi
        done

        NEW_SPACE_MB=$(df -m "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
        if [ -z "$NEW_SPACE_MB" ] || [ "$NEW_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
            printf "❌ 仍然没有足够的空间来安装。正在中止。
"
            exit 1
        else
            printf "✅ 新位置可用空间充足：%dMB
" "$NEW_SPACE_MB"
        fi
    else
        printf "✅ 安装所需空间充足：%dMB
" "$AVAILABLE_SPACE_MB"
    fi
}

# -----------------------------
# 自身更新检查
# -----------------------------
check_self_update() {
    printf "
🔍 正在检查脚本更新...
"

    LOCAL_VERSION="$(grep -m1 '^# Version:' "$SCRIPT_PATH" | awk '{print $3}' | tr -d '
')"
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0000-00-00"

    if ! wget -q -O "$TMP_NEW_SCRIPT" "$SCRIPT_URL"; then
        printf "⚠️ 无法检查更新（网络或 GitHub 问题）。
"
        return 1
    fi

    REMOTE_VERSION="$(grep -m1 '^# Version:' "$TMP_NEW_SCRIPT" | awk '{print $3}' | tr -d '
')"
    [ -z "$REMOTE_VERSION" ] && REMOTE_VERSION="0000-00-00"

    printf "📦 当前版本: %s
" "$LOCAL_VERSION"
    printf "🌐 最新版本:  %s
" "$REMOTE_VERSION"

    # 比较版本（字符串比较足够用于 YYYY-MM-DD 形式）
    if [ "$REMOTE_VERSION" \> "$LOCAL_VERSION" ]; then
        printf "
检测到新版本。现在更新吗？[y/N]: "
        read -r ans
        case "$ans" in
            y|Y)
                printf "⬆️ 正在更新...
"
                cp "$TMP_NEW_SCRIPT" "$SCRIPT_PATH.new" && chmod +x "$SCRIPT_PATH.new"
                printf "✅ 已完成升级。正在重启脚本...
"
                exec "$SCRIPT_PATH.new" "$@"
                ;;
            *)
                printf "⏭️ 跳过更新，继续使用当前版本。
"
                ;;
        esac
    else
        printf "✅ 你已经运行的是最新版本。
"
    fi

    rm -f "$TMP_NEW_SCRIPT" >/dev/null 2>&1
    printf "
"
}

# -----------------------------
# 持久化选项提示（保持在 sysupgrade 时保留）
# -----------------------------
prompt_persist() {
    if [ -n "$AVAILABLE_SPACE_MB" ] && [ "$AVAILABLE_SPACE_MB" -ge "$REQUIRED_SPACE_MB" ] && [ ! -L "$INSTALL_DIR" ]; then
        printf "
💾 是否希望 OpenSpeedTest 在固件升级后保留？[y/N]: "
        read -r persist
        if [ "$persist" = "y" ] || [ "$persist" = "Y" ]; then
            # 核心路径
            grep -Fxq "$INSTALL_DIR" /etc/sysupgrade.conf 2>/dev/null || echo "$INSTALL_DIR" >> /etc/sysupgrade.conf
            grep -Fxq "$STARTUP_SCRIPT" /etc/sysupgrade.conf 2>/dev/null || echo "$STARTUP_SCRIPT" >> /etc/sysupgrade.conf
            grep -Fxq "$CONFIG_PATH" /etc/sysupgrade.conf 2>/dev/null || echo "$CONFIG_PATH" >> /etc/sysupgrade.conf

            # 也持久化任何 rc.d 的符号链接（S* 和 K*）
            if [ -n "$STARTUP_SCRIPT" ]; then
                SERVICE_NAME=$(basename "$STARTUP_SCRIPT")
                for LINK in $(find /etc/rc.d/ -type l -name "[SK]*${SERVICE_NAME}" 2>/dev/null); do
                    grep -Fxq "$LINK" /etc/sysupgrade.conf 2>/dev/null || echo "$LINK" >> /etc/sysupgrade.conf
                done
            fi

            printf "✅ 已启用持久化。
"
            return
        fi
    fi
    remove_persistence
    printf "✅ 已禁用持久化。
"
}

# -----------------------------
# 移除持久化记录
# -----------------------------
remove_persistence() {
    sed -i "|$INSTALL_DIR|d" /etc/sysupgrade.conf 2>/dev/null
    sed -i "|$STARTUP_SCRIPT|d" /etc/sysupgrade.conf 2>/dev/null
    sed -i "|$CONFIG_PATH|d" /etc/sysupgrade.conf 2>/dev/null

    if [ -n "$STARTUP_SCRIPT" ]; then
        SERVICE_NAME=$(basename "$STARTUP_SCRIPT")
        sed -i "|/etc/rc.d/[SK].*${SERVICE_NAME}|d" /etc/sysupgrade.conf 2>/dev/null
    fi
}

# -----------------------------
# 选择下载源
# -----------------------------
choose_download_source() {
    printf "
🌐 请选择下载源：
"
    printf "1️⃣ 官方仓库
"
    printf "2️⃣ GL.iNet 镜像
"
    printf "请选择 [1-2]: "
    read -r src
    printf "
"
    case $src in
        1) DOWNLOAD_URL="https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip" ;;
        2) DOWNLOAD_URL="https://fw.gl-inet.com/tools/script/Speed-Test-main.zip" ;;
        *) printf "❌ 无效选项，已默认选择官方仓库。
"; DOWNLOAD_URL="https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip" ;;
    esac
}

# -----------------------------
# 检测内部 IP
# -----------------------------
detect_internal_ip() {
    INTERNAL_IP="$(uci get network.lan.ipaddr 2>/dev/null | tr -d '
')"
    [ -z "$INTERNAL_IP" ] && INTERNAL_IP="<路由器_IP>"
}

# -----------------------------
# 安装依赖
# -----------------------------
install_dependencies() {
    DEPENDENCIES="curl:curl nginx:nginx-ssl timeout:coreutils-timeout unzip:unzip wget:wget"

    for item in $DEPENDENCIES; do
        CMD=${item%%:*}   # 命令名
        PKG=${item##*:}   # 包名

        # 使用 BusyBox 兼容的 tr 转为大写以便展示
        CMD_UP=$(printf "%s" "$CMD" | tr 'a-z' 'A-Z')
        PKG_UP=$(printf "%s" "$PKG" | tr 'a-z' 'A-Z')

        if ! command -v "$CMD" >/dev/null 2>&1; then
            printf "${CYAN}📦 %s${RESET} 未安装，正在安装 %s...
" "$CMD_UP" "$PKG_UP"
            if [ "$opkg_updated" -eq 0 ]; then
                opkg update >/dev/null 2>&1
                opkg_updated=1
            fi

            if opkg install "$PKG" >/dev/null 2>&1; then
                printf "${CYAN}✅ %s${RESET} 安装成功。
" "$PKG_UP"
                if [ "$PKG" = "nginx-ssl" ]; then
                    /etc/init.d/nginx stop >/dev/null 2>&1
                    /etc/init.d/nginx disable >/dev/null 2>&1
                    if [ -f /etc/nginx/conf.d/default.conf ]; then
                        rm -f /etc/nginx/conf.d/default.conf
                    fi
                fi
            else
                printf "${RED}❌ 无法安装 %s。请检查网络或 opkg 配置。${RESET}
" "$PKG_UP"
                exit 1
            fi
        else
            printf "${CYAN}✅ %s${RESET} 已安装。
" "$CMD_UP"
        fi
    done
}

# -----------------------------
# 安装 OpenSpeedTest
# -----------------------------
install_openspeedtest() {
    install_dependencies
    check_space
    choose_download_source

    # 如果有旧的 PID 文件则尝试停止
    if [ -s "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            printf "⚠️ 检测到已有运行中的 OpenSpeedTest，正在停止...
"
            kill "$OLD_PID" && printf "✅ 已停止。
" || printf "❌ 停止失败。
"
            rm -f "$PID_FILE"
        fi
    fi

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1
    [ -d Speed-Test-main ] && rm -rf Speed-Test-main

    # 使用后台 wget 下载并显示 spinner
    wget -O main.zip "$DOWNLOAD_URL" >/dev/null 2>&1 &
    wget_pid=$!
    spinner "$wget_pid" "下载 OpenSpeedTest"
    wait "$wget_pid"

    # 解压并显示 spinner
    unzip -o main.zip >/dev/null 2>&1 &
    unzip_pid=$!
    spinner "$unzip_pid" "解压文件"
    wait "$unzip_pid"
    rm -f main.zip

    # 生成 NGINX 配置
    cat <<EOF > "$CONFIG_PATH"
worker_processes  auto;
worker_rlimit_nofile 100000;
user nobody nogroup;

events {
    worker_connections 2048;
    multi_accept on;
}

error_log  /var/log/nginx/error.log notice;
pid        $PID_FILE;

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        server_name _ localhost;
        listen $PORT;
        root $INSTALL_DIR/Speed-Test-main;
        index index.html;

        client_max_body_size 10000M;
        error_page 405 =200 \$uri;
        access_log off;
        log_not_found off;
        error_log /dev/null;
        server_tokens off;
        tcp_nodelay on;
        tcp_nopush on;
        sendfile on;
        resolver 127.0.0.1;

        location / {
            add_header 'Access-Control-Allow-Origin' "*" always;
            add_header 'Access-Control-Allow-Headers' 'Accept,Authorization,Cache-Control,Content-Type,DNT,If-Modified-Since,Keep-Alive,Origin,User-Agent,X-Mx-ReqToken,X-Requested-With' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header Cache-Control 'no-store, no-cache, max-age=0, no-transform';
            if (\$request_method = OPTIONS) {
                add_header Access-Control-Allow-Credentials "true";
                return 204;
            }
        }

        location ~* ^.+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|woff2|svg)\$ {
            access_log off;
            expires 365d;
            add_header Cache-Control public;
            add_header Vary Accept-Encoding;
        }
    }
}
EOF

    # 生成启动脚本
    cat <<EOF > "$STARTUP_SCRIPT"
#!/bin/sh /etc/rc.common
START=81
STOP=15
start() {
    if netstat -tuln | grep -q ":$PORT"; then
        printf "⚠️  端口 $PORT 已被占用，无法启动 OpenSpeedTest 的 NGINX。
"
        return 1
    fi
    printf "正在启动 OpenSpeedTest NGINX 服务..."
    /usr/sbin/nginx -c $CONFIG_PATH
    printf " ✅
"
}
stop() {
    if [ -s $PID_FILE ]; then
        kill \$(cat $PID_FILE) 2>/dev/null
        rm -f $PID_FILE
    fi
}
EOF
    chmod +x "$STARTUP_SCRIPT"
    "$STARTUP_SCRIPT" enable 2>/dev/null || true

    # 启动 NGINX
    "$STARTUP_SCRIPT" start

    # 检测内部 IP 并提示
    detect_internal_ip
    printf "
✅ 安装完成。请访问： ${CYAN}http://%s:%d${RESET}
" "$INTERNAL_IP" "$PORT"
    prompt_persist
    press_any_key
}

# -----------------------------
# 诊断工具
# -----------------------------
diagnose_nginx() {
    printf "
🔍 正在运行 OpenSpeedTest 诊断...

"

    detect_internal_ip

    if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        printf "✅ OpenSpeedTest 的 NGINX 进程正在运行（PID: %s）
" "$(cat "$PID_FILE")"
    else
        printf "❌ OpenSpeedTest 的 NGINX 进程 未在运行
"
    fi

    if netstat -tuln | grep ":$PORT " >/dev/null; then
        printf "✅ 端口 %d 已在 %s 上监听
" "$PORT" "$INTERNAL_IP"
        printf "🌐 你可以通过以下地址访问 OpenSpeedTest： ${CYAN}http://%s:%d${RESET}
" "$INTERNAL_IP" "$PORT"
    else
        printf "❌ 端口 %d 在 %s 上未监听
" "$PORT" "$INTERNAL_IP"
    fi

    press_any_key
}

# -----------------------------
# 卸载所有内容
# -----------------------------
uninstall_all() {
    printf "
🧹 这将移除 OpenSpeedTest、启动脚本及 /www2 内容。
"
    printf "确定要继续吗？[y/N]: "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        printf "❌ 卸载已取消。
"
        press_any_key
        return
    fi

    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    [ -L "/www2" ] && rm -f "/www2"

    [ -f "$CONFIG_PATH" ] && rm -f "$CONFIG_PATH"

    if [ -f "$STARTUP_SCRIPT" ]; then
        "$STARTUP_SCRIPT" disable 2>/dev/null || true
        rm -f "$STARTUP_SCRIPT"
    fi

    remove_persistence
    printf "✅ OpenSpeedTest 已成功卸载。
"
    press_any_key
}

# -----------------------------
# 启动界面与检查更新
# -----------------------------
command -v clear >/dev/null 2>&1 && clear
printf "%b
" "$SPLASH"
check_self_update "$@"

# -----------------------------
# 主菜单
# -----------------------------
show_menu() {
    clear
    printf "%b
" "$SPLASH"
    printf "%b
" "${CYAN}请选择一个操作：${RESET}
"
    printf "1️⃣  安装 OpenSpeedTest
"
    printf "2️⃣  运行诊断
"
    printf "3️⃣  卸载所有内容
"
    printf "4️⃣  检查更新
"
    printf "5️⃣  退出
"
    printf "请选择 [1-5]: "
    read opt
    printf "
"
    case $opt in
        1) install_openspeedtest ;;
        2) diagnose_nginx ;;
        3) uninstall_all ;;
        4) check_self_update "$@" && press_any_key;;
        5) exit 0 ;;
        *) printf "%b
" "${RED}❌ 无效选项。${RESET}"; sleep 1; show_menu ;;
    esac
    show_menu
}

# -----------------------------
# 启动
# -----------------------------
show_menu
