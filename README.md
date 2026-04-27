# 潜水员戴夫 PC/安卓存档同步脚本

这是一个 Windows 批处理脚本，用来在 Steam 版《潜水员戴夫》和 TapTap 安卓版之间同步存档。

## 适用路径

电脑端默认读取：

```text
C:\Users\你的用户名\AppData\LocalLow\nexon\DAVE THE DIVER\SteamSData\1918815201
```

手机端默认写入：

```text
/storage/emulated/0/Android/data/com.xd.dave.tap.cn/files/SData
```

如果你的 Steam 账号目录不是 `1918815201`，脚本会自动尝试使用 `SteamSData` 下找到的账号目录。

## 使用方法

1. 关闭电脑和手机上的游戏。
2. 手机开启 USB 调试，并用数据线连接电脑。
3. 双击 `点我启动-潜水员戴夫.cmd`。
4. 按菜单选择同步方向。

常用选项：

- `1`：电脑存档同步到手机。
- `2`：手机存档同步到电脑。
- `3`：只导出到手机中转目录，适合继续用 MT 管理器手动复制。
- `7`：只检查手机游戏目录和中转目录里的存档状态，不会改文件。

## 关于 Android/data 限制

部分手机系统不允许 ADB 直接写入 `Android/data`。遇到这种情况时，脚本会把文件放到：

```text
/sdcard/DAVE_SYNC_TRANSFER/SData
```

然后你可以用 MT 管理器把这个目录里的文件复制到：

```text
/storage/emulated/0/Android/data/com.xd.dave.tap.cn/files/SData
```

## 备份

脚本在覆盖前会自动备份目标端存档：

- `DAVE_Mobile_Backup`：手机旧存档备份。
- `DAVE_PC_Backup`：电脑旧存档备份。

默认最多保留 10 份备份。

## ADB

`adb` 目录里保留了运行脚本需要的最小 Windows ADB 文件。ADB 来自 Android SDK Platform-Tools，相关声明见 `adb/NOTICE.txt`。
