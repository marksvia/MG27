# MG27

在设备上直接读写 `com.apple.MobileGestalt.plist`，支持 iOS 27。

底层用 [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) 的
App Group 符号链接沙盒逃逸。功能对齐 [frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit)，
界面和实现重写。

---

## 功能

### 区域

- **Siri AI 强开** —— `RegionCode` 写 `LL`，`RegionInfo` 不动 不影响爱思
- **恢复国行区域码** —— `RegionCode` 写回 `CH`

### 显示与外观

| 功能 | 写入 |
|---|---|
| 灵动岛能力 | `YlEtTtHlNesRBMal1CqRaA` = 1 |
| 全天候显示 | `2OOJf1VhaM7NxfRok3HbWQ`、`j8/Omm6s1lsmTDFsXjsBfA` = 1 |
| AOD 通透 | `ykpu7qyhqFweVMKtxNylWA` = 1 |
| 关闭壁纸视差 | `UIParallaxCapability` = 0 |
| Liquid Glass 低性能 | `SAGvsp6O6kAQ4fEfDJpC4Q` = 1 |
| 关闭 Liquid Glass 低性能 | `SAGvsp6O6kAQ4fEfDJpC4Q` = 0 |

### 硬件能力

| 功能 | 写入 |
|---|---|
| 开关机提示音 | `QHxt+hGLaBPbQJbXiUJX3w` = 1 |
| 充电上限菜单 | `37NVydb//GP/GrhuTN+exg` = 1 |
| 轻点唤醒 | `yZf3GTRMGTuwSV/lD7Cagw` = 1 |
| 相机控制设置 | `CwvKxM2cEogD3p+HYgaW0Q`、`oOV1jhJbdV3AddkcCg0AEA` = 1 |
| Apple Pencil 设置 | `yhHcB0iH0d1XzPO/CFd3ow` = 1 |
| 操作按钮设置 | `cT44WE1EohiwRzhsZ8xEsw` = 1 |
| 碰撞 SOS | `HCzWusHQwZDea6nNhaKndw` = 1 |

### iPad 能力

| 功能 | 写入 |
|---|---|
| 台前调度 | `qeaj75wk3HF4DwQ8qbIi7g` = 1 |
| 安装 iPad 应用 | `9MZ5AdH43csAUajl/dU+IQ` = `[1, 2]` |
| iPadOS 模式 | 五个能力位 + 重写 CacheData |

### 内部 / 研究

内部安装标记、内部存储视图、安全研究设备模式。每项两个按钮：

- **启用** —— 键写成 `1`
- **清除** —— 删除该键

行右侧显示当前 `键存在` / `键缺失`。

### 灵动岛

选择设备子类型，写 `ArtworkDeviceSubType` 和灵动岛支持标志。

### 机型名

改写「关于本机」里显示的机型名，写 `ArtworkDeviceProductDescription`。

### 字段编辑

CacheExtra 和顶层键都能逐条编辑，支持 string / int / float / bool / data /
array / dict 七种类型，数组和字典用 JSON 表示。带搜索。

### 备份

每次写入前自动备份到 `Documents/MobileGestalt Backups`。支持手动备份、
从文件导入、导出、恢复、删除。

### 其他

- 顶部显示设备名、法规型号、`RegionCode`、`RegionInfo`、字段数、UDID（点击复制）
- 写入后自动 respring，6 秒无响应可手动退出
- 从 Mac 用 `glctl.sh` 驱动，不用点屏幕

---

## 区域键说明

MobileGestalt 里跟区域有关的有两个键：

| 键 | 明文名 | 值 | 作用 |
|---|---|---|---|
| `h63QSdBCiT/z0WU6rdQv6Q` | `RegionCode` | `CH` / `LL` | Apple Intelligence 资格门读取 |
| `zHeENZu+wbg7PUprwNwBWg` | `RegionInfo` | `CH/A` / `LL/A` | 「关于本机」显示的型号尾缀 |

「Siri AI 强开」只写 `RegionCode`，`RegionInfo` 保持原值。两个开关互斥。

---

## 写入流程

1. 改内存里的 plist（不落盘）
2. 点「应用」→ 自动备份当前 plist
3. 原地重写 inode（`ftruncate` + `write` + `fsync`），保留属主和 xattr
4. 写失败自动回滚原始字节
5. 写完整份回读，逐字节比对
6. 开启区域校验时，额外确认 `RegionCode` 等于期望值
7. 成功后触发 respring

---

## 从 Mac 驱动

```sh
cd ~/Downloads/gestaltedit

./glctl.sh dump                 # 导出 plist 到 App Documents
./glctl.sh siri                 # 区域码写 LL
./glctl.sh region CH            # 区域码写 CH
./glctl.sh key "YlEtTtHlNesRBMal1CqRaA=1"
./glctl.sh pull                 # 把导出的 plist 拉到本地
```

---

## 出包

签名信息不写死在仓库里，从环境变量或同目录的 `.env.local` 读：

```sh
cat > .env.local <<'EOF'
IDENT="iPhone Distribution: Your Name (TEAMID)"
APP_ID="TEAMID.com.example.mg27"
TEAM_ID="TEAMID"
APP_GROUPS="group.abc.1 group.abc.2"
EOF

./build.sh
# → ./MG27.ipa
```

`.env.local` 已在 `.gitignore` 里，不会被提交。也可以直接传环境变量：

```sh
IDENT="iPhone Distribution: Name (TEAMID)" \
APP_ID="TEAMID.com.example.mg27" \
TEAM_ID="TEAMID" \
APP_GROUPS="group.abc.1 group.abc.2" \
./build.sh
```

`build.sh` 会用这些值生成 `entitlements.plist`，并把 `Info.plist` 里的
`CFBundleIdentifier` 改成 `APP_ID` 去掉 `TEAMID.` 前缀后的部分。
描述文件路径默认找 `~/Library/MobileDevice/Provisioning Profiles/描述文件.mobileprovision`，
可以用 `PROFILE` 覆盖。

---

## 文件

| 文件 | 说明 |
|---|---|
| `worse_query.m` / `.h` | 沙盒逃逸，逐阶段错误码 + `worse_query_last_errno()` |
| `GestaltAccess.m` / `.h` | 取 extension、读写 plist、写失败回滚 |
| `GestaltModels.swift` | plist 模型、七种值类型编解码、设备档案 |
| `GestaltTweaks.swift` | 19 项预设、灵动岛 / 机型名 / iPadOS CacheData 改写 |
| `GestaltViewModel.swift` | 状态、应用、备份、错误处理、UDID 读取 |
| `GestaltBackupStore.swift` | 备份落盘与列举 |
| `MGTheme.swift` | 调色板、卡片、开关、hero、分段按钮等视觉组件 |
| `ContentView.swift` | 三个 tab 的界面 |
| `NeoSpringView.swift` | WebKit respring（带超时和退出） |
| `AutomationCommand.swift` | 无界面命令行入口 |
| `build.sh` | 编译 + 签名 + 打包（签名配置走环境变量） |
| `glctl.sh` | Mac 端驱动脚本 |

---

## 和 GestaltEdit 的差异

| | GestaltEdit | MG27 |
|---|---|---|
| 逃逸手法 | bad_query（class 13 + `../../..` part domain） | worse_query（class 7 符号链接） |
| 版本门禁 | 硬编码 beta1~beta4 六个 build 号 | 只判 `majorVersion == 27` |
| 区域改写 | 两个键都改（CH→LL, CH/A→LL/A） | 只改 RegionCode |
| 内部项 | 只能清除 | 启用 / 清除双按钮 |
| respring | 无超时 | 6 秒超时 + 退出按钮 |
| UDID | 不显示 | 顶部显示，可复制 |
| 界面 | 系统 Form | 自绘卡片流 + 浮动导航 |

---

## 注意

- 改坏的 MobileGestalt 可能让系统功能异常，严重时要刷机。只在自己的设备上用。
- 写完必须 respring 或重启才生效；`MobileGestalt.plist` 在内存里有缓存。
- 只改 `CacheExtra` 里已存在的键最安全；新增键系统可能不认。
- 改灵动岛子类型和机型名会动 `ArtworkTraits` 字典。
- 系统语言和 Siri 语言都要是英文（`en-US`）才会出现 Apple Intelligence。

---

## 许可

`worse_query.m` / `.h` 来自 [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)，GPL-3.0。
其余部分见仓库 LICENSE。
