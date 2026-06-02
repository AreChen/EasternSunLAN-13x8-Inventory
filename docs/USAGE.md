# 使用说明

## 快速安装

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\install.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN"
```

## 只校验不修改

```powershell
.\tools\validate.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN"
```

## 不修改 D2RLAN 用户设置

如果你只想改文件，不想让脚本设置 `ExpandedInventory=true`：

```powershell
.\tools\install.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN" -SkipD2RLANSetting
```

不推荐这样做，除非你知道启动器不会覆盖布局。

## 不生成备份

```powershell
.\tools\install.ps1 -ModRoot "<D2R>\Mods\EasternSunLAN" -NoBackup
```

日常使用不推荐 `-NoBackup`。
