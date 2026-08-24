# MetaPencil Review Request

## Repository

- URL: `https://github.com/Qiushi0919/MetaPencil`
- Visibility: Public by explicit owner request; license pending
- Branch: `main`
- Base commit: `9a42c5b64019523c71af7849f7b8895ecca4efe0`
- Target commit: `f4279de24deaa25ed0163485e26b471ec94912ff`
- Pull Request: not created

## 本次任务

把经过校验的交接包建立为安全、可追溯、适合 Codex/ChatGPT 协作的 Git 仓库，不改核心算法；可见性后来按项目负责人要求改为 Public。

## 修改前模型

原始交接快照已有理想 2-bit 时延相消、点散射体复回波和 RD 结果，但没有 Git 历史、位置感知宏格模型或统一仓库协作机制。

## 修改后模型

核心算法未修改；仅明确记录现有 L0–L2 能力和 L3/L4 缺口。

## 关键公式

- 四时延分区因子：`S_n = (1/4) Σ_p exp(-j 2π n d_p)`。
- 当前通道混合：`response = Σ_k w_k response_k`，其中 `w_k` 仅由 `tile_map` 计数得到。

## 关键文件

- `AI_CONTEXT.md`
- `PROJECT_STATE.json`
- `AGENTS.md`
- `tests/test_harmonic_model.py`
- `outputs/smoke_test/run_manifest.json`

## 测试结果

见 `TEST_RESULTS.md`；872 项基线校验、4 个 Python 断言、凭据扫描和 MATLAB 烟雾测试均通过。

## 结果图

`outputs/smoke_test/harmonic_suppression.png`

## 已知限制

宏格位置尚未进入有限口径散射；H_k 尚未对应散射点子集；Git LFS 尚未启用；第三方材料许可仍待复核。

## 需要重点判断的问题

1. 对当前 `tile_map` 和 H_k 两个模型边界的审计结论是否准确、表述是否足够克制？
2. P0 Issue #1/#2 的验收标准能否区分面积混合近似和位置感知有限口径模型？
3. 能量守恒、PSLR/ISLR 和非理想四态误差测试还缺哪些关键指标？
