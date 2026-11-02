## 2026-11-02 16:45 — Cao X 波段内存保护中断后续跑，并设定时检查

- H1V1 已完成五频点求解，原生日志总求解250秒；求解后history未改变且8个元件复核通过。H2V1于16:39:22中断，memory_abort.json记录可用内存3.3561 GiB低于3.5 GiB保护线；不是结构校验失败，原结果保留。
- 在新目录Results_xband_ideal_v1r1启动剩余6态，启动可用内存9.8687 GiB。保护线调整为2.5 GiB，仍只中止自身求解器；几何、网格、4线程和五频点设置不变。冻结输入及启动记录见同一review packet的resume_plan.json/resume_launch.json。
- 用户要求定时，已创建当前聊天每10分钟检查一次的Cao X波段监测；无变化安静，完成或异常报告，完成后暂停。预计恢复后30–45分钟，不能保证具体完成时刻；内存或超时可再次中断。
- 尚未分析七态幅相，不声明2-bit或9–10 GHz达标。模型仍是理想SP4T的粗网格全波诊断。验证：新启动脚本编译通过，已完成态求解后核验记录检查通过，实际续跑进程已部署。

## 2026-11-02 16:33 — Cao X 波段七态粗算已启动

- 用户追加“迁移模型赶紧开始求解”，已启动固定迁频几何的7态诊断。H1V1于16:32:40进入求解，4线程、9.5 GHz三轮自适应、9/9.25/9.5/9.75/10 GHz五个直接采样，每态900秒上限，整体19:02截止。其余六态正常完成/核验后自动接续。
- 已核对新结构及8个理想开关元件，冻结case SHA见launch.json。每态求解后先保存并读回实际history/8元件，核验通过后才导出曲线和进入下一态。启动可用内存9.328 GiB；保留本任务低于3.5 GiB可用内存时中止保护，不干预其他求解器。
- 本轮仍为理想SP4T，无真实BGSA14GN10 X波段性能承诺。尚无完成态结果，不宣称工作频段或2-bit达标。结果目录Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102/Results_xband_ideal_v1；已完成的41页PPT保留原频段七态图与迁频结构，后续结果另行追加。

## 2026-11-02 — Cao 七态图补入文献 PPT，并建立 9–10 GHz 初始结构

- 按用户最新优先级，先建立9.5 GHz中心的迁频几何；原3.6 GHz复现仍未收敛且未通过论文2-bit判据，不把原频段粗算转写为成功基线。
- xqs原生CST建立7个条件态，38条history/态及8个理想开关元件/态读回一致；10个RF铜网络无短接，56个元件端点和参数匹配，检查RF/孔径/侧视原生图。周期12.505263 mm、贴片9.663158 mm；无源缩放3.6/9.5，RF焊盘0.25 mm和间距0.4 mm保留，局部引出采用连续过渡。最小间隙0.037895 mm，仍为几何初稿，未作加工定版。
- 明确改变模型层级：原16个BGSA等效RLC/输出电容，迁频初稿改为8个理想串联R（ON 0.01Ω/OFF 1e9Ω，L=C=0）。BGSA14GN10官方上限6 GHz，未将该器件模型外推至X波段；实际开关、封装和材料频散待核对。本次没有调用求解器，没有9–10 GHz幅相达标结论。
- 原文献PPT追加39–41页，第40页为用户指定七态相量图；区分相对目标误差H32.0°/V51.2°与循环相邻间隔误差H28.5°/V48.9°。原38页及40个图表工作簿字节保留；41页已渲染、新增页逐页检查，文件/布局/图表检查通过，未声称PowerPoint应用打开验证。保留原文件备份，验证后复制回原PPT路径。
- 新模型和证据在Unitcell-qiushi/Cao双SP4T_9至10GHz迁频_20261102；review packet 20261102_c64fe55_cao_xband，commit/参数/模型/归一化/路径/哈希见manifest。下一步为固定几何进行9–10 GHz七态诊断，先检查结构再读结果，并选择适用X波段的真实开关；不覆盖原频段历史结果。

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
