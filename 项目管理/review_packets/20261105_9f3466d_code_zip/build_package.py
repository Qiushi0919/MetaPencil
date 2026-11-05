"""Package the verified lightweight report source and one result, without rerunning MATLAB."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import zipfile

PACKET = Path(__file__).resolve().parent
ROOT = PACKET.parents[2]
COMMIT = '9f3466d30329d6a55e348f3771a0a1e6ef428f7c'
RUN = '20261105_174457_036'
CODE = ROOT / 'Matlab-code/code'
RESULT = CODE / 'results_report' / RUN
DEST = ROOT / 'Matlab-code/code.zip'
SOURCE_NAMES = ['main_study.m', 'main_study_spatial.m', 'plot_report_results.m',
                'airplane_scatter_points.mat']
RESULT_NAMES = [
    'cells.csv', 'channels.csv', 'tiles.csv', 'checks.json', 'figure_manifest.json',
    'image_comparison.json', 'parameters.json', 'point_metrics.json', 'run_manifest.json',
    'sar_display_check.json', 'source_main_study_spatial.m', 'source_plot_report_results.m',
    'fig3_12_sar_comparison_minus80.png', 'fig3_1_point_unmodulated.png',
    'fig3_2_reference_unmodulated.png', 'fig3_3_ordinary_vs_delay.png',
    'fig3_13_slow_time_and_point_controls.png',
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    run = json.loads((RESULT / 'run_manifest.json').read_text())
    assert run['status'] == 'PASS' and not run['full_complex_arrays_saved']
    assert not run['editable_figures_saved']
    payload = {}
    for name in SOURCE_NAMES:
        data = (CODE / name).read_bytes()
        committed = subprocess.check_output(['git', 'show', f'{COMMIT}:Matlab-code/code/{name}'], cwd=ROOT)
        assert data == committed, f'Unverified source change: {name}'
        payload[f'code/{name}'] = data
    for name, key in [('main_study_spatial.m', 'script_sha256'),
                      ('plot_report_results.m', 'plot_script_sha256'),
                      ('airplane_scatter_points.mat', 'input_sha256')]:
        assert sha(payload[f'code/{name}']) == run[key]
    for name in RESULT_NAMES:
        payload[f'code/results_report/{RUN}/{name}'] = (RESULT / name).read_bytes()
    payload['code/使用说明.txt'] = f'''MetaPencil MATLAB 轻量版：代码与已验证结果

1. 解压 code.zip 后，在 MATLAB 中打开 code/main_study.m，点击“运行”。
2. 已有5张报告图、参数和指标在 code/results_report/{RUN}/。
3. 每次运行会新建结果目录，仅保存PNG、参数、指标和运行记录；本次实测7.43 MB。
4. 计算流程保留：快慢编码、单元理想复响应、阵内传播相位、相干求和、复回波和RD聚焦。
5. 配置：9–10 GHz、1 GHz带宽、Fs=9.6 GSa/s、PRF=3072 Hz、水平16×16阵面；三模型图共同参考−80～0 dB。
6. 测试环境MATLAB R2025a，本机含绘图约8分钟。单元采用理想四态模型，未包含实际全波或实测单元响应。

airplane_scatter_points.mat是运行必需的小型输入数据。本包不含旧的完整回波MAT、FIG或历史大结果。
代码版本：{COMMIT}
'''.encode('utf-8')
    manifest = {
        'source_commit': COMMIT, 'entrypoint': 'code/main_study.m',
        'result_directory': f'code/results_report/{RUN}',
        'model_level': run['model_level'], 'normalization': run['normalization'],
        'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                  for name, data in sorted(payload.items())],
    }
    payload['code/package_manifest.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
    temporary = PACKET / 'code.zip.tmp'
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 5, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(temporary) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == set(payload)
        for name in z.namelist():
            path = PurePosixPath(name)
            assert path.parts[0] == 'code' and '..' not in path.parts and not path.is_absolute()
            assert z.read(name) == payload[name]
        with tempfile.TemporaryDirectory(prefix='metapencil-code-zip-check-') as folder:
            z.extractall(folder)
            for name, data in payload.items():
                assert (Path(folder) / name).read_bytes() == data
    assert len(payload) == 23
    assert [name for name in payload if name.endswith('.mat')] == ['code/airplane_scatter_points.mat']
    assert not any(name.endswith('.fig') or '.DS_Store' in name for name in payload)
    if DEST.exists():
        backup = PACKET / 'previous_code.zip'
        assert not backup.exists(), 'Existing backup must not be overwritten.'
        shutil.copy2(DEST, backup)
    os.replace(temporary, DEST)
    audit = {
        'status': 'PASS', 'source_commit': COMMIT, 'archive': str(DEST.relative_to(ROOT)),
        'archive_bytes': DEST.stat().st_size, 'archive_decimal_MB': DEST.stat().st_size / 1e6,
        'archive_sha256': sha(DEST.read_bytes()), 'entries': len(payload),
        'uncompressed_bytes': sum(map(len, payload.values())),
        'crc_pass': True, 'extracted_bytes_match': True, 'source_matches_verified_run': True,
        'only_mat_file_is_required_small_input': True, 'old_large_results_included': False,
        'matlab_recomputed_for_packaging': False, 'package_manifest': manifest,
    }
    (PACKET / 'archive_manifest.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k != 'package_manifest'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
