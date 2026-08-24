# Git LFS 策略与后续安装

初始化机器未安装 `git-lfs`，因此本次没有制造无法在当前环境验证的 LFS 指针。交接包内单个已收录文件均低于 GitHub 100 MiB 硬限制；原始 50–304 MiB MAT/FIG 已由交接包排除并记录在 `file_manifest.csv`。

## 当前策略

- 已导入的小型基线二进制保持普通 Git 对象，保证标签可直接克隆和校验。
- 新增或修改的、不可轻易重算且大于 25 MiB 的 PPTX/PDF/DOCX/STL/MAT 优先使用 Git LFS。
- 可重算的大 MAT/FIG/视频不应仅因为可用 LFS 就入库；应保存运行清单和生成方法。
- 任何接近 100 MiB 的单文件在提交前必须处理，不允许直接推送。

## 安装后执行

```bash
brew install git-lfs
git lfs install --local
git lfs track "path/to/specific-large-file.mat"
git add .gitattributes path/to/specific-large-file.mat
git commit -m "data(lfs): track required large research asset"
git lfs ls-files
```

不要对整个历史仓库运行未经审阅的 `git lfs migrate`；它会重写历史，违反本仓库安全策略。

