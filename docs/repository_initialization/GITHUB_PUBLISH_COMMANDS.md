# GitHub synchronization/recovery commands

The private repository and Git-ready tag are fully published. Normal future synchronization is:

```bash
cd '/Users/qiushi/Library/CloudStorage/OneDrive-个人/谢秋实 本科/B 实习/5 Meta浙江大学/MetaPencil_Git_Workspace/MetaPencil'
git push origin main
git push origin --tags
```

Verify afterward:

```bash
gh repo view Qiushi0919/MetaPencil --json visibility,defaultBranchRef,url
git status
git log --oneline --decorate -8
git ls-remote --heads --tags origin
```

Offline recovery from the bundle:

```bash
git clone MetaPencil_20260824.git.bundle MetaPencil
cd MetaPencil
git remote add origin https://github.com/Qiushi0919/MetaPencil.git
git push -u origin main
git push origin --tags
```

Never use `--force` for these commands.
