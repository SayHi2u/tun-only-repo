# Net Probe

一个没有第三方依赖的 Android 探针，用来验证「某个 app 的流量实际从哪个网卡出去」。

## 作用

打开 app 时只读取并显示：

- 默认网络接口（`ConnectivityManager` / `LinkProperties`）；
- 默认网络类型（Wi-Fi / 移动数据 / VPN / 以太网 / 蓝牙）；
- 默认网络 IP；
- 所有已启用接口和地址。

**打开 app 不会自动联网。** 只有点击“测试出口”才会向目标 `IP:端口` 发起一次 TCP 连接，并显示：

- 目标；
- 本地 IP；
- 出口接口（`tun0` / `wlan0` / `rmnet` 等）；
- 耗时。

默认目标是 `223.5.5.5:443`（阿里 DoH，大陆可达），可以在输入框改成其他国内目标，例如：

- `119.29.29.29:443`（腾讯 DoH）
- `180.76.76.76:443`（百度 DoH）

## 结果怎么看

- **成功 + 本地 IP `10.10.14.1` + 出口 `tun0`**：走了 v2rayNG 的 VPN，符合预期。
- **成功 + `192.168.x.x` + 出口 `wlan0`**：走了 Wi-Fi，模块规则没有作用到这个 app。
- **成功 + `10.x`/`100.x` + 出口 `rmnet`/`ccmni`**：走了移动数据，模块规则没有作用到这个 app。
- **成功 + 出口 `tun1`**：走了其他 tun，不是 v2rayNG 的 `tun0`。
- **失败 + `ECONNREFUSED` / `EPERM` / `EACCES` + VPN 关闭**：很可能是 iptables `REJECT` 命中，数据没有发到物理网卡；这是规则生效的预期结果。
- **失败 + `SocketTimeout`**：目标不可达、被墙或端口被过滤；换一个国内目标再试。
- **失败 + `ENETUNREACH`**：没有可用路由；VPN 关闭且规则 REJECT 时也可能出现。

## 让探针代表目标 app

探针只能看到**它自己**的默认网络和测试连接出口，看不到微博/抖音的流量。要让它代表目标 app：

1. 在模块 WebUI 中勾选 `com.codewhale.netprobe`；
2. 在 v2rayNG 分应用代理中让探针也走 VPN；
3. 开 VPN：应显示 `tun0`，连接成功；
4. 关 VPN：应连接失败。

目标 UID 是否被规则约束，最终以模块 WebUI 的 iptables 验证为准。

## 构建

```bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
./scripts/build-netprobe.sh
```

产物：`dist/netprobe.apk`。

默认使用脚本生成的 debug keystore 签名，密码固定为 `android`，**不要把这个 keystore 提交到仓库**。正式签名：

```bash
KEYSTORE=/path/to/release.keystore \
KEYSTORE_PASS=... \
KEY_ALIAS=... \
KEY_PASS=... \
./scripts/build-netprobe.sh
```

## 安装

```bash
adb install -r dist/netprobe.apk
```

包名：`com.codewhale.netprobe`。
