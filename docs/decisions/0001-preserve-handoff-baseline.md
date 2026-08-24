# ADR-0001：保留交接快照为不可变基线

- 状态：Accepted
- 日期：2026-08-24

## 决策

将 ZIP 解压后的 873 个文件先原样提交，并以 `handoff-v1.0-20260824` 标记；所有 Git 规范、AI 文档、测试和 CI 在后续提交中增加。

## 原因

这样可以直接比较 Git 基线和内部 872 项 SHA-256 清单，避免仓库初始化动作与核心研究快照混在一起。

## 后果

原始小写 `project_state.json` 因 macOS 默认大小写不敏感文件系统无法与根目录规范化 `PROJECT_STATE.json` 并存，故在后续协作文档提交中原样移动为 `docs/handoff/project_state.original.json`；基线标签仍保留其原始根路径与字节。后续不得移动或改写基线标签。
