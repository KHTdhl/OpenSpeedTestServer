# OpenSpeedTest 安装脚本（适用于 GL.iNet 路由器上的 NGINX）

```
   _____ _          _ _   _      _   
  / ____| |        (_) \ | |    | |  
 | |  __| |  ______ _|  \| | ___| |_
 | | |_ | | |______| | . ` |/ _ \ __|
 | |__| | |____    | | |\  |  __/ |_
 \_____|______|   |_|_| \_|\___|\__|

         OpenSpeedTest for GL-iNet
```

> 📡 轻松在 OpenWRT / GL.iNet 路由器上部署 OpenSpeedTest + NGINX

---

## ✨ 功能特点

* 📦 安装并配置 [NGINX](https://nginx.org/) 运行 [OpenSpeedTest](https://openspeedtest.com/)
* 🔧 自定义 NGINX 配置，避免与 GL.iNet 原有 Web 管理界面冲突
* 📁 安装目录为 `/www2`，自动检测机身存储空间是否足够
* 🔗 若内部存储不足，可自动创建指向外接存储（SD 卡、U 盘）的软链接
* ⬆️ 支持固件升级后的持久化
* 🔁 自动创建开机启动脚本与停止脚本
* 🧹 完整卸载，可清理配置、启动脚本、软链接等内容
* 🩺 附带诊断工具检查 NGINX 是否正常运行与端口可达性
* ⤵️ 支持自动下载脚本最新版本（测试中）
* 🧑‍💻 交互式命令行菜单，所有操作带确认提示
* 🆓 GPLv3 开源许可
* 🧪 已在 GL-BE9300、GL-BE3600、GL-MT3000、GL-MT1300（含 SD 卡）等设备上测试

---

## 🚀 安装步骤

1. **通过 SSH 登录路由器：**

```
ssh root@192.168.8.1
```

2. **下载脚本：**

```
wget -O install_openspeedtest.sh https://raw.githubusercontent.com/phantasm22/OpenSpeedTestServer/main/install_openspeedtest.sh && chmod +x install_openspeedtest.sh
```

3. **执行脚本：**

```
./install_openspeedtest.sh
```

4. **按提示选择安装、诊断或卸载。**

---

## 🌐 打开测速页面

安装完成后，在浏览器访问：

```
http://<路由器IP>:8888
```

例如：

```
http://192.168.8.1:8888
```

---

## 🔍 脚本菜单选项

运行脚本后可选择：

1. **安装 OpenSpeedTest** —— 安装 NGINX、配置环境、下载 SpeedTest 页面
2. **运行诊断工具** —— 检查 NGINX 是否正常运行、端口是否开放
3. **卸载所有内容** —— 删除所有配置、启动脚本与文件
4. **退出脚本**

---

## 🧹 卸载方式

重新执行脚本，选择 **3. 卸载所有内容**。

或手动执行：

```
killall nginx
rm -f /etc/nginx/nginx_openspeedtest.conf
/etc/init.d/nginx_speedtest disable
rm -f /etc/init.d/nginx_speedtest
rm -rf /www2/Speed-Test-main
```

---

## 👤 作者

**phantasm22**

欢迎提出建议与 PR！

---

## 📜 许可证

本项目使用 **GNU GPL v3.0** 协议开源，详情请参阅官方许可文件。
