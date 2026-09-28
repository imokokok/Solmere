# 本地与 CI 的完整检查 · 2026-09-26

## 这次失败的根因

[失败运行 36233120809](https://github.com/imokokok/Solmere/actions/runs/36233120809) 对应 `d03a560`。失败来自 `tests/test_reference_layout.gd` 的旧断言：要求菜板层高于锅底、遮住伸出的锅柄。用户刚要求锅柄完整可见，生产布局已修复，旧断言却仍把正确的新行为判作失败。

本机同样能复现 77 项布局检查中的该错误，不是 Linux 专属报错或 Godot 下载失败。上次只运行了六组定向回归，未覆盖该布局入口；所以本地“相关检查通过”不能代表完整 CI 通过。

现在保留实际修复，断言检查菜板位于抬高的锅柄下方，同时锅底仍在食物层下方、刀在菜板上方。没有跳过、删除布局测试或关闭 CI。之前新增的 GPU 锅柄像素检查继续验证真实画面；本轮没有改动烹饪状态或重录视频。

完整复跑还发现测试存档隔离缺陷：`Time.get_ticks_usec()` 从每次引擎启动重新计数，不能保证不同进程的目录唯一。`serving_continuity` 撞到已有测试目录后读出两份菜谱，导致原本应为一份的严格断言偶发失败。清单内 31 个脚本的 33 处此类路径改用 128 位随机后缀；盛盘测试额外检查初始菜谱为空，仍保留保存后只有一份菜谱的断言。没有清理玩家存档或更改游戏的保存逻辑。

## 唯一清单与共享入口

`tools/regression_suite.json` 保存固定 Godot 版本及全部 43 个 CI 回归入口，包括容易漏掉的布局测试。`tools/run_checks.py` 用 Python 3 标准库执行；macOS/Linux/GitHub Actions 和 Windows PowerShell 包装都调用它，避免临时脚本抽取清单或手选几个套件后误报全量通过。

完整入口依次检查：

1. Godot 版本确为 4.7.2。
2. 导入工程，检测资源/脚本导入错误。CI 使用全新 checkout；本地重新导入当前工程，不声称删除了全部本地缓存。
3. headless 启动 120 帧。
4. 完整执行清单中的 43 个 Godot 脚本。某项失败后继续，收集后续失败，不只暴露第一个问题。
5. 审计外部录音的来源、哈希、许可记录及 PCM。

退出 0 还不够：每项必须出现自己的完成标记，且不能含 `ERROR`、`SCRIPT ERROR` 或 `FAIL`。超时、无完成标记、缺失脚本、重复清单和错误引擎版本都不能报告完整通过。原有 `PASS`、`*_PASSED checks=…`、素材 alpha 审计成功标记均保留兼容。

8 项检查程序单元测试覆盖：真实标记格式、先 PASS 后报错、非零退出、引擎早退无完成标记、ANSI 着色错误、超时、失败后继续运行下一项及布局入口登记。GitHub Actions 运行这些单元测试后再调用完整游戏入口。

## 使用和取证

在小游戏目录运行：

```sh
python3 -m unittest discover -s tools -p test_checks.py
python3 tools/run_checks.py --godot /path/to/godot
```

Windows：

```powershell
./tools/test.ps1 -GodotPath C:\path\Godot.exe
# 如需指定 Python：追加 -PythonPath C:\path\python.exe
```

默认结果在 `.runtime/checks/summary.json` 与逐步 `.log`，可用 `--output-dir <目录>` 指定。清单中的新增测试应在 JSON 登记；不能用定向测试结果代替完整结果。

Actions 保留原有 push / pull_request 触发及 Godot 4.7.2 固定版本，增加 15 分钟 job 上限，并在成功或失败后上传 `restaurant-check-results`，只包含本次检查目录的日志和汇总。无隐藏失败的 `continue-on-error`，不改变 GitHub 权限或关闭通知。

推送前完整运行共享入口；推送后按本次提交 SHA 查询 Actions，等实际完成并确认结论，不能把本地绿色或提交成功当作远程绿色。

## 本次验证

本机完成检查程序 8 项测试，以及共享入口的 43/43 个 Godot 脚本、导入、120 帧启动和音频审计。[完整汇总](../qa/20260926-ci-fix/summary.json) 保留每项的退出码与日志位置；[布局日志](../qa/20260926-ci-fix/tests_test_reference_layout_gd.log) 为 77 项通过。新的 CI 结论以修复提交对应的远程运行记录为准。

全量通过后，另连续复跑盛盘/菜谱保存测试三次，三次均通过 17 项检查，包括初始为空和重开后仅一份菜谱；[重复运行记录](../qa/20260926-ci-fix/serving-isolation-repeats.json) 和各次日志保留在同一目录。Windows PowerShell 包装未在本机运行，本次本地验证使用 macOS Python 入口，远程验证使用 Linux Python 入口。

本轮为检查目标与执行入口修复。既有二维渲染/物理近似、GPU 与系统人工鼠标验收的区别沿用既有专项说明，不额外声称人工试玩或人耳验收。

## 2026-09-29 主工程首次导入

完整 Solmere 在资源缓存为空时，主题和自动加载脚本会先于贴图导入读取纹理。
在没有编辑器打开的源码目录，使用：

```sh
python3 tools/import_main_project.py --godot /path/to/godot
```

这是仓库根目录的工具。先用临时最小配置导入资源，再逐字节恢复原配置，
然后以完整主工程重新导入。两个阶段都要求进程正常退出且没有引擎错误。
失败或超时恢复配置；强制结束 Python 后会保留备份，工具拒绝静默覆盖它。
六项工具测试覆盖恢复、超时、残留备份、错误日志与非零退出。CI 保留两阶段日志。
星云两份原始 Draco GLB 仅作源文件保留；运行时仍使用已转换的原生场景。
