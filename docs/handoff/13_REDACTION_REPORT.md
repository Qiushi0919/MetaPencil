# 脱敏报告

## 扫描结果

- 未在可扫描的 MATLAB、Python、JavaScript、Markdown、TXT、CSV、JSON、YAML 中发现明文 API Key、密码、访问令牌或 Bearer Token 模式。
- 发现 2 个原始文本文件含个人机器的绝对路径。
- 未在本报告中输出任何秘密原文。

## ZIP 副本中的替换

| 交接包相对文件 | 类型 | 处理 |
|---|---|---|
| `source/2 暑假_两个月仿真任务/Week 4 0813之前/歼36_4x4机群_sar_code_2D/Deep_Research_交接文档_单边带谐波抑制.md` | 本地工作区绝对路径 | 替换为 `<REDACTED_WORKSPACE_ROOT>` |
| `source/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列/build_freedom_presentation.mjs` | 用户缓存/工作区绝对路径 | 替换为 `<REDACTED_USER_CACHE>` 与 `<REDACTED_WORKSPACE_ROOT>` |

原始项目未修改。脱敏只发生在独立交接副本。

## 保留的信息

- 0818 PPT 中的汇报人/作者姓名作为项目归属信息保留；它不是访问凭证，且任务要求保留原始汇报材料。
- 原始目录名中可能包含课程/实习上下文，但 ZIP 的根清单使用项目相对路径，不记录 `/Users/...`。
- `file_manifest.csv` 只包含项目相对路径和SHA256，不含用户主目录。

## 后续建议

若交接包将公开上传，而非在研究组内交接，应再次审查 PPT/PDF/Word 的作者元数据、姓名、单位和文献版权；本次没有修改二进制报告的元数据。
