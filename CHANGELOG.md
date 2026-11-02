## 2026-11-02 15:54 — Cao 修订版七条件态完成，尚未达到论文2-bit判据

- 同几何同设置完成H1V1/H2V1/H3V1/H4V1/H1V2/H1V3/H1V4共7态，3.6GHz单直接点，三轮/4线程，累计求解832.362秒。每态先核验实际保存history与16元件，再读曲线；7态几何相同、仅ON/OFF选择变化，224个原生阻抗样本匹配。首态另外导出并检查RF/孔径/侧视原生图，源工程SHA不变。
- H循环相邻相位变化−118.536/−93.489/−62.922/−85.053度；V为−138.930/−92.300/−46.807/−81.963度。最大相邻误差28.536/48.930度，均未通过论文90±20度标准；最大首态相对误差32.025/51.230度。最差共极化幅度H−1.331/V−1.476dB；没有相位排序、共轭或拟合。
- 七态末次ΔS依次.0443065/.0311794/.105274/.035958/.11695/.138932/.0879943，均未满足连续两轮<.03，不将粗算误差全部归因于结构；不宣称论文复现成功或完整16组合独立性。H切换对固定V相位最大扰动1.883度，V切换对固定H最大0.945度，仅为粗算条件态证据。
- 保留源尺寸缺项：L2的输入端参考及局部扇出/折弯采用显式假设；模型图核验通过不等于作者CAD一致。下一步应在固定几何下先加密排除数值漂移，再继续按论文核对剩余参考定义。当前无运行中的solver，未启动PPT或迁频。
- 证据、七态CSV和相量图在Unitcell-qiushi/论文结构一致性修正_20261102/Results_cao_l2launch_v3six；本地packet20261102_c64fe55_paper_alignment/cao_l2launch_v3。全部原始数据保留；脱敏记录进入PR#12，CAD/论文/机器日志不公开。

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
