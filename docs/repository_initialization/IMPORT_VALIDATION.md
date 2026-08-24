# Import validation

验证日期：2026-08-24（Asia/Shanghai）

## 结果

- ZIP 外层 SHA-256 与交接记录一致。
- `unzip -tq`：压缩数据无错误。
- 解压后普通文件：873 个。
- `CHECKSUMS_SHA256.txt`：872/872 通过，0 个失败。
- `file_manifest.csv`：1056 条原始项目记录，包含路径、大小、SHA-256、用途、收录状态和排除原因。
- 原始交接快照已独立提交并打 `handoff-v1.0-20260824` 注释标签。

## 敏感信息初筛

对可读文本进行了以下模式扫描：私钥头、AWS Access Key、GitHub PAT/token、OpenAI 风格密钥和常见 `password/token/secret/api_key = value` 赋值。

- 高置信密钥模式：0 个候选文件。
- 通用赋值模式：2 个候选文件，经核对均为 MATLAB 文本解析变量 `token/tokens`，不是访问凭据。
- 二进制 PDF/PPTX/DOCX/MAT/STL 未按纯文本正则解包扫描；公开前仍需进行许可与元数据复核。

扫描只证明当前规则未命中高置信凭据，不替代人工安全审阅。

