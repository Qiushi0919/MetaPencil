# Review packets

每项可审阅工作建立：

```text
review_packets/YYYYMMDD_<shortsha>_<topic>/
├── SUMMARY.md
├── COMMIT_INFO.md
├── CHANGED_FILES.txt
├── TEST_RESULTS.md
├── QUESTIONS_FOR_CHATGPT.md
└── artifacts/                 # 只放必要的小型图表
```

私有仓库需要外部 AI 审阅时，可将单个 packet 打包为 `MetaPencil_Review_<shortsha>.zip`；不得把凭据或未获许可的大附件放入 packet。

