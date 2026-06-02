# 风险说明

## 物品丢失风险

13x8 背包会新增右侧 3 列。如果补丁被卸载、EasternSunLAN 更新覆盖了布局，或 D2RLAN 把 UI 回退到旧模板，新列里的物品可能不可见。不同环境下，保存/重新进入游戏时也可能出现物品丢失。

建议：

- 安装前备份角色存档和共享箱子存档。
- 卸载前先把新增右侧 3 列清空。
- 更新 EasternSunLAN 后先检查背包仍是 13x8，再继续游玩。

## D2RLAN 开关风险

D2RLAN 的 Expanded Inventory 开关可能会在启动器操作时覆盖 UI layout。安装脚本会同步 expanded 模板，并把 `ExpandedInventory` 设置为 `true`。不要在启动器里关闭 Expanded Inventory，否则可能把 UI 回退到旧模板。

## 版本兼容风险

本补丁按 EasternSunLAN 3.11.09 的文件结构编写。其它版本可能修改了 `inventory.txt`、布局文件或 D2RLAN 模板路径，不能保证直接兼容。

## 联机一致性

多人联机时，所有玩家应使用一致的 EasternSunLAN 数据、D2RLAN 配置和启动参数。库存尺寸不一致可能导致显示、保存或交互异常。

