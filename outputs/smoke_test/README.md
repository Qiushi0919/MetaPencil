# Smoke-test artifacts

该目录保存可提交的小型验证输出。`run_manifest.json` 记录源 commit、分支、真实命令、模型层级和运行时间。

运行：

```bash
python3 tests/run_local_matlab_smoke.py
```

此测试只验证理想谐波系数、四时延零陷、二维幅度、面积分配和 ±8 m 频率映射，不是完整 700 散射点 SAR 图的重算。

