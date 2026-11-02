## 2026-11-02 — Cao nominal RF pin-layout reconstruction

- Native CST RF polygons and 16 lumped elements checked after datasheet-based pad-layout correction. Main dimensions/RLC/state order unchanged; L2 reference, absolute placement and fanout remain inferred.
- Nets are disjoint and series endpoints lie inside metal. Native plan views verified after correcting export aspect ratio; source CAD hash unchanged. These checks do not establish exact author-CAD or paper-result reproduction.
- Solver launch stopped at existing available-memory guard before invoking CST solve. No new S-parameters for this revision.
- Audit: 项目管理/review_packets/20261102_c64fe55_cao_pinlayout/audit.json. Paper PDFs, CAD files, raw logs and machine details remain local.

# Changelog

## Unreleased

- 在仓库 README 增加谢秋实 / Qiushi Xie 的中英文个人主页链接。

- 按项目负责人明确要求将 GitHub 仓库从 Private 改为 Public，并启用禁止 force push/deletion 的 `main` 分支保护。
- 保持 `LICENSE_PENDING.md`：Public 可见性不等于开源许可，第三方材料许可仍待核查。
- 建立 Git/GitHub 协作规范、自动检查和 review packet 流程。
- 把位置感知宏格模型和空间散射点分区列为 P0。
- 创建私有 GitHub 仓库、8 个研究 Issues 和 3 个 milestones。
- 增加仓库/凭据/理想谐波测试，并记录一次实际 MATLAB R2025a 烟雾测试。
- GitHub Actions 工作流已推送，并在 Git-ready 标签 commit 上运行成功。

## handoff-v1.0-20260824

- 从经过 SHA-256 校验的 `MetaPencil_Code_Handoff_20260824.zip` 导入原始研究快照。
- 未修改核心 MATLAB 算法、历史结果或模型结论。
