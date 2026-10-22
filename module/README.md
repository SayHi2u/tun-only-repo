# Tun Only (KernelSU 模块 + WebUI)

强制选中的应用**只能从 v2rayNG 的 `tun0` 出站**，拒绝物理网卡、移动数据和其他 tun 接口。规则按 **包名 → 当前 UID** 动态生成，不写死 UID。

## 规则是正向白名单，不是反向排除

`apply.sh` 生成的链是：

```text
-A TUN_ONLY_APPS -o lo -j ACCEPT
-A TUN_ONLY_APPS -o tun0 -j ACCEPT
-A TUN_ONLY_APPS -j REJECT
```

只明确允许 `lo` 和 `tun0`，其余全部 `REJECT`。因此：

- 不需要知道 Wi-Fi 接口是 `wlan0` 还是别的名字；
- 不需要知道移动数据接口是 `rmnet_data0`、`ccmni0` 还是别的名字；
- `tun1`、其他 VPN 接口、热点接口也一并被拒绝；
- 只要不是 `tun0`，就不可能出站。

`lo` 是本地回环，不是物理网卡，允许它不会导致公网泄露。

## 模块自带 WebUI

- 浏览/搜索已安装应用，勾选需要强制走 `tun0` 的应用；
- 手动输入未列出的包名；
- 保存后自动重跑 `apply.sh`，立即应用新配置；
- 一键验证 `tun0`、iptables 链、OUTPUT 引用、生效 UID 和日志。

## 重要前提

1. 目标应用必须在 **v2rayNG 分应用代理**中实际走 VPN：
   - 常规模式：勾选目标应用；
   - 绕行模式：不要勾选目标应用（绕行模式勾选 = 直连）。
   否则它没有 `tun0` 路径，会被规则完全断网。
2. 你当前环境里 v2rayNG 开启后新增的是 **`tun0`**；`tun1` 在关闭 v2rayNG 时也存在，不是 v2rayNG 的接口。规则只允许 `tun0`，不使用 `tun+`。
3. 如果以后 v2rayNG 的接口名变成 `tun1`，修改 `config.conf` 里的 `TUN_IF`，然后保存/重新应用或重启。

## 安装 / 更新

1. 把 `tun-only-ksu.zip` 传到手机。
2. KernelSU 管理器 → 模块 → 从本地安装，选择 zip。
3. 重启手机。
4. 在模块列表里点击 **WebUI**（模块有 `webroot` 就会显示）。

Termux 也可以：

```bash
su -c 'ksud module install /sdcard/Download/tun-only-ksu.zip'
```

## WebUI 使用

- **刷新**：重新读取应用列表和当前状态。
- **勾选应用**：写入 `packages.conf` 的目标包名。
  - 勾选的应用会自动置顶，已选包名会显示在列表上方的 chips 中；
  - 点 chip 右侧的 `×` 可以取消勾选；
  - 列表上方有“勾选的应用置顶”开关，默认开启，可以关闭；
  - 勾选后约 700ms 重排，避免连续勾选时列表频繁跳动；搜索状态和滚动位置会保留。
- **显示系统应用**：默认关闭，只显示用户应用。打开后会加载系统应用，并在名称旁显示“系统”标签；关闭后未勾选的系统应用会隐藏，已勾选的系统应用仍会显示，方便取消。
  - 系统应用数量较多，首次打开需要加载几秒；加载结果会缓存到本次页面。
  - **系统应用可能共享 UID**。勾选一个系统应用可能同时影响同 UID 的其他系统组件（包括 `android` / `system_server`），可能导致系统 UI、网络、无线调试异常。只在明确知道后果时使用。
  - 极少数 special 系统包可能不在 KernelSU 的 `listPackages` 列表里；需要时用下面的“手动输入包名”。
- **手动输入包名**：每行一个，适合应用列表里未显示的目标（special 系统包、工作资料、双开），也适合**预先填写尚未安装的包名**。
  - 未安装的包名会保留在 `packages.conf`，`apply.sh` 暂时记一条 `not installed` 并跳过；
  - 安装该包名后，如果 ROM 支持 `inotifyd`，会监听包数据库并在安装完成后自动重跑 `apply.sh`；
  - 本模块**不做定时轮询**（不耗电）。如果“验证规则”里显示“包变化监听: 未运行”，安装新包后点“重新应用规则”或重启手机即可。
- **保存并应用**：写入 `packages.conf` 后自动执行 `apply.sh`，不需要重启手机，也不需要重启 v2rayNG。
  - 注意：勾选只是页面内的临时状态，**必须点“保存并应用”**才会写入配置；直接退出 WebUI 会丢失未保存的勾选。
- **重新应用规则**：只重跑 `apply.sh`，不改包名。
- **验证规则**：显示 tun0、IPv4/IPv6 链、OUTPUT 引用、uids.state、packages.conf 和最近日志。
- **复制**：输出栏右上角有“复制”按钮，可以一键复制验证/执行输出，方便贴到聊天或日志里。
  - WebView 的剪贴板 API 不一定可用，按钮会优先用 `document.execCommand('copy')`，失败再尝试 `navigator.clipboard`。

WebUI 通过 KernelSU 的 `ksu.exec` 以 root 执行命令；不需要额外给任何 app root 权限。

如果 WebUI 里应用列表为空（旧版 KernelSU 的 `listPackages` 不可用），直接用手动输入包名即可。

## WebUI 状态徽章与常见问题

- **看不到系统应用**：确认打开了列表上方的“显示系统应用”。如果某个系统包仍然不在列表里（例如 `android` 等 special 包），在“手动输入包名”里直接填包名。
- **勾选系统应用后系统异常**：系统应用经常共享 UID。例如 `android`、`com.android.systemui`、`com.android.settings` 可能落在同一个 system UID；iptables 按 UID 匹配，勾选其中一个会影响同 UID 的所有组件。无线调试显示 tun IP、系统 UI 网络异常、设置打不开等，都可能是这个原因。先取消勾选并“重新应用规则”。
- **验证输出只显示一行（例如 IPv4 链只有 `-j REJECT`、OUTPUT 只有一条 UID）**：这是旧版 WebUI 的读取问题。KernelSU 的 `ksu.exec` 对多行 stdout 不可靠，可能只保留最后一行；规则实际上可能已经完整。1.7 起所有多行命令都会先 `tr '\n' '|'` 转成单行，再由页面拆分，不再截断。
  - 升级前想确认，直接在 Termux 执行：
    ```bash
    su -c 'iptables -S TUN_ONLY_APPS'
    su -c 'iptables -S OUTPUT | grep TUN_ONLY_APPS'
    ```
    如果看到 3 条链规则和每个 UID 一条 OUTPUT 引用，说明规则已经成功。
- **tun0 已连接 / tun0 不存在**：`ip -o link show tun0` 的结果。v2rayNG 关闭时 tun0 不存在是正常的；此时规则会阻断目标 app。
- **规则链正常**：`TUN_ONLY_APPS` 链存在，且有 `lo`/`tun0` 放行和 `REJECT`。
- **规则链不存在**：链根本没有建立。点“重新应用规则”；如果仍失败，看 `apply.log`。常见原因是开机时 `apply.sh` 还没执行、`iptables` 不在 PATH、或模块脚本执行失败。
- **规则不完整**：链存在，但缺少 `-o tun0 -j ACCEPT` 或 `-j REJECT`。检查 `config.conf` 里的 `TUN_IF` 是否和实际接口名一致。
- **UID x/y**：`x` 是 `iptables -S OUTPUT` 中实际找到的 UID 引用数，`y` 是 `uids.state` 里记录的 UID 数。
  - `2/2`：两个 UID 都有规则，正常。
  - `1/2`：state 里有 2 个 UID，但只有 1 个 UID 有 OUTPUT 引用。可能是旧 UID 残留、第二条规则添加失败，或 state 里包含重复/旧数据。点“重新应用规则”会先清理再按包名重建；如果仍不一致，看 `apply.log`。
- **生效 UID 2 个、包名 1 个**：一个包名对应两个 UID 是正常的，常见于多用户、工作资料、应用双开；`apply.sh` 使用 `--user all` 会覆盖这些 UID。也可能是重装 app 后旧 UID 残留；新版 `apply.sh` 会去重并在每次应用前清掉同一 UID 的旧引用。
- **勾选后退出 WebUI 又变回未勾选**：勾选只是页面内的临时状态，必须点 **“保存并应用”** 才会写入 `packages.conf`。页面现在会在有未保存修改时显示提示。
  - 如果点了保存仍然丢失，检查“验证规则”里的 `packages.conf` 内容；为空说明写入失败。也可以手动执行：
    ```bash
    su -c 'cat /data/adb/modules/tun-only-ksu/packages.conf'
    ```
- **多包保存失败/只读回最后一个包名**：旧版用 heredoc 多行写入，KernelSU 的 `ksu.exec` 对多行命令/输出不可靠，多包时可能只保留一行。1.5 起改用单行 `printf ... | tr ... > packages.conf` 写入，读回时 `tr '\n' '|'` 变成单行再校验，不再依赖多行输出。
- **“保存并应用”和“重新应用规则”的区别**：
  - **保存并应用**：把当前勾选/手动包名写入 `packages.conf`，然后执行 `apply.sh`。修改列表时用这个。
  - **重新应用规则**：不修改 `packages.conf`，只执行 `apply.sh`。用于重装 app 后 UID 变化、重启后规则丢失、或想手动刷新规则。

## 验证规则是否生效

WebUI 里点“验证规则”，或手动执行：

```bash
su -c 'ip -o link show tun0'
su -c 'iptables -S TUN_ONLY_APPS'
su -c 'iptables -S OUTPUT | grep TUN_ONLY_APPS'
su -c 'cat /data/adb/modules/tun-only-ksu/uids.state'
su -c 'tail -n 30 /data/adb/modules/tun-only-ksu/apply.log'
```

预期：

```text
-A TUN_ONLY_APPS -o lo -j ACCEPT
-A TUN_ONLY_APPS -o tun0 -j ACCEPT
-A TUN_ONLY_APPS -j REJECT
```

以及 OUTPUT 中每个目标 UID 一条引用。

功能测试：

1. 开启 v2rayNG：`tun0` 存在，目标应用正常联网；
2. 关闭 v2rayNG：`tun0` 消失，目标应用无法联网；
3. 其他未选应用不受影响；
4. `iptables -L TUN_ONLY_APPS -v -n` 的 REJECT 计数会增加。

## 重启 / 重装后的行为

- **重启**：`service.sh` 等待 `sys.boot_completed` 后自动执行 `apply.sh`，规则恢复。
- **应用更新/清数据**：包名和 UID 不变，规则继续有效。
- **卸载重装**：UID 通常会变。`service.sh` 启动的 `inotifyd` 会监听 `/data/system/packages.xml`，安装完成后自动重跑 `apply.sh`。
  - 如果 `inotifyd` 或该路径在你的 ROM 上不可用，模块不会启动轮询；重装后点“重新应用规则”或重启。
  - 如果“验证规则”里显示“包变化监听: 未运行”，重装后重启，或在 WebUI 里点“重新应用规则”。
- **多用户/工作资料/双开**：`apply.sh` 优先使用 `cmd package list packages -U --user all`，覆盖同一包名的多个 UID。
- **卸载模块**：KernelSU 管理器卸载后重启；`uninstall.sh` 会尽量清理规则。

## 需不需要给 app 持久化 root

不需要。

- 模块的 `service.sh` / `apply.sh` 由 KernelSU 以 root 运行；
- WebUI 由 KernelSU 管理器提供 root shell；
- 微博、抖音、v2rayNG、探针 app 都不需要 root；
- 只有在 Termux 里手动执行 `su -c ...` 验证时，才需要给 Termux 授权 su。

## 探针 app（Net Probe）

`netprobe.apk` 是一个独立的 Android 探针，用来**避免用目标应用做验证**：

- 打开 app 只显示默认网络接口、默认网络 IP、所有启用的接口，不会自动联网；
- 测试目标默认是 **`223.5.5.5:443`（阿里 DoH，大陆可达）**，可以在输入框改成别的 IP/端口；
- 备选国内目标：`119.29.29.29:443`（腾讯 DoH）、`180.76.76.76:443`（百度 DoH）；
- 点击“测试出口”才向目标发起一次 TCP 连接，显示目标、本地 IP、出口接口、耗时；
- 不携带任何业务数据。

### 结果解读

- **成功 + 本地 IP `10.10.14.1` + 出口 `tun0`**：本 app 的流量走了 VPN，模块规则和 v2rayNG 捕获都正常。
- **成功 + 本地 IP `192.168.x.x` + 出口 `wlan0`**：走了 Wi-Fi 物理网卡，模块规则没有作用到本 app。
- **成功 + 本地 IP `10.x`/`100.x` + 出口 `rmnet`/`ccmni`**：走了移动数据，模块规则没有作用到本 app。
- **成功 + 出口 `tun1`**：走了其他 tun，不是 v2rayNG 的 `tun0`。
- **失败 + `ECONNREFUSED` + 本地源 IP 是 `192.168.x.x`/`10.x`，且 VPN 关闭**：这是 **iptables 的 REJECT 命中**，连接在本地 OUTPUT 层被拒绝，数据没有发到物理网卡。错误里的 `from /192.168.x.x` 只是 socket 原本绑定的本地源地址，不代表流量真的出去了。这是模块生效的预期结果。
- **失败 + `EPERM`/`EACCES`**：同样可能是规则 REJECT；VPN 关闭时通常是预期结果。
- **失败 + `SocketTimeout`**：目标不可达、被墙或端口被过滤；先换一个国内目标再试。
- **失败 + `ENETUNREACH`**：没有可用路由；VPN 关闭且规则 REJECT 时也可能出现。

### 让探针代表目标 app

1. 在模块 WebUI 中勾选 `com.codewhale.netprobe`（或手动输入）；
2. 在 v2rayNG 分应用代理中让探针也走 VPN；
3. 开 VPN：探针应显示 `tun0`，测试成功；
4. 关 VPN：探针应测试失败。

注意：普通 app 无法看到其他 app 的流量走哪个网卡。探针显示的是**它自己**的默认网络和测试连接出口；目标 UID 的规则是否生效，以 WebUI 的 iptables 验证为准。探针的测试流量即使泄露，也只是一次到国内 DoH IP 的 TCP 连接，不会触发微博/抖音的业务流量。

## 注意

- 规则只允许 `lo` 和 `tun0`；局域网、投屏、打印机等物理网络访问也会被拒绝。需要时在 `apply.sh` 的 IPv4 链里加 `-d 192.168.0.0/16 -j ACCEPT`（IPv6 同理）。
- 如果 `ip6tables` 不存在，IPv6 不会被覆盖；`apply.log` 会记录警告。
- `tun1` 不是 v2rayNG 的接口，规则不会放行它。
- 如果使用 AFWall+ 等其他防火墙，避免它们覆盖 `OUTPUT` 链里的这些规则。
- 模块只影响 `packages.conf` 中的 UID，不会全局断网。
