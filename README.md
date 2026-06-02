# EasternSunLAN 13x8 Inventory

这是给 `EasternSunLAN 3.11.09` 使用的独立背包扩展补丁。它把玩家背包从 `10x8` 扩展到 `13x8`，并同步 D2RLAN 的 expanded inventory 模板，避免启动器开关把布局覆盖回旧尺寸。

本仓库是脚本式插件包，不重新分发完整 MOD 或游戏资源。你需要先安装好 Diablo II: Resurrected、EasternSunLAN 和 D2RLAN。

## 支持范围

- 目标 MOD：`EasternSunLAN`
- 目标版本：`3.11.09`
- 背包尺寸：`13x8`
- 启动要求：需要 `-txt`
- D2RLAN：建议保持 `ExpandedInventory=true`

## 安装

1. 关闭游戏和 D2RLAN 启动器。
2. 从 GitHub Release 下载 `EasternSunLAN-13x8-Inventory-v3.11.09-13x8.2.zip`。
3. 解压到任意目录，例如：

```powershell
<任意工具目录>\EasternSunLAN-13x8-Inventory
```

4. 运行安装脚本，把 `-ModRoot` 指向你的 EasternSunLAN MOD 目录：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\install.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN"
```

5. 启动参数必须包含 `-txt`。常见参数类似：

```text
-mod EasternSunLAN -txt
```

6. 进入游戏后测试：把物品放到新增的右侧 3 列，保存退出，再重新进入确认物品仍在。

## 校验

安装后可以运行：

```powershell
.\tools\validate.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN"
```

成功时会输出：

```text
13x8 inventory validation ok
```

## 卸载 / 回退

安装脚本会在 MOD 目录下创建备份：

```text
.backup\13x8-inventory\<timestamp>\
```

回退到最近一次备份：

```powershell
.\tools\uninstall.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN"
```

也可以指定某个备份目录：

```powershell
.\tools\uninstall.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN" -BackupDir "<D2R>\Mods\EasternSunLAN\.backup\13x8-inventory\20260602-154000"
```

## 风险点

- 如果你把物品放在新增的右侧 3 列，然后卸载补丁或让布局回退到 10x8/10x4，这些格子里的物品可能不可见，甚至在某些情况下丢失。
- 安装或卸载前建议备份角色存档和共享箱子存档。
- EasternSunLAN 更新后可能覆盖 `inventory.txt` 或 UI layout 文件；更新 MOD 后通常需要重新运行本补丁。
- D2RLAN 如果手动关闭 Expanded Inventory，可能会应用 `retailish` 回退模板，导致 13x8 数据和旧 UI 不一致。安装脚本会把 `MyUserSettings.json` 中的 `ExpandedInventory` 设置为 `true`，但你仍应避免在启动器里关闭它。
- 这个补丁只针对 EasternSunLAN 3.11.09。其它版本或其它 MOD 需要重新检查布局和 `inventory.txt`。
- 多人联机时，建议所有参与者使用一致的 MOD 数据和启动参数。
- 手柄布局已经同步为 `13x8`，但仍建议实际进游戏确认光标导航是否符合你的习惯。
- Release 包包含 13x8 背景 sprite overlay；缺少这些资源时，逻辑可能是 13x8，但画面仍会像 10 列。

## 修改了哪些文件

安装脚本会修改这些目标文件：

```text
EasternSunLAN.mpq\data\global\excel\inventory.txt
EasternSunLAN.mpq\data\global\ui\layouts\_profilehd.json
EasternSunLAN.mpq\data\global\ui\layouts\_profilelv.json
EasternSunLAN.mpq\data\global\ui\layouts\playerinventoryoriginallayouthd.json
EasternSunLAN.mpq\data\global\ui\layouts\playerinventoryexpansionlayouthd.json
EasternSunLAN.mpq\data\global\ui\layouts\playerinventoryoriginallayout.json
EasternSunLAN.mpq\data\global\ui\layouts\controller\playerinventoryoriginallayouthd.json
EasternSunLAN.mpq\data\global\ui\layouts\controller\playerinventoryexpansionlayouthd.json
EasternSunLAN.mpq\data\D2RLAN\Expanded\Inventory\playerinventoryoriginallayouthd_expanded.json
EasternSunLAN.mpq\data\D2RLAN\Expanded\Inventory\playerinventoryexpansionlayouthd_expanded.json
EasternSunLAN.mpq\data\hd\global\ui\panel\inventory\classic_background_expanded.sprite
EasternSunLAN.mpq\data\hd\global\ui\panel\inventory\background_expanded.sprite
EasternSunLAN.mpq\data\hd\global\ui\controller\panel\inventorypanel\v2\inventorybg_classic_expanded.sprite
EasternSunLAN.mpq\data\hd\global\ui\controller\panel\inventorypanel\v2\inventorybg_expanded.sprite
EasternSunLAN.mpq\MyUserSettings.json
```

`MyUserSettings.json` 只会被保留原设置并将 `ExpandedInventory` 设为 `true`。

## 开发者使用

构建 Release zip：

```powershell
.\tools\build-release.ps1 -Version "v3.11.09-13x8.2"
```

生成文件位于：

```text
dist\EasternSunLAN-13x8-Inventory-v3.11.09-13x8.2.zip
```
