## 用 Nix / {rix} 管理 R 与 Python 开发环境（快速指南）
# 目的

用 Nix + {rix} 为每个项目生成可复现的开发环境（R + R 包 + Python + Python 包），并用 direnv 自动激活。

# 典型文件
project/
├─ gen-env.R         # 用 rix 生成 default.nix
├─ default.nix       # rix 生成的 Nix 表达式（不要手动编辑太多）
├─ .envrc            # direnv 自动加载 (use nix)
├─ utils.R, utils.py
├─ tests/
│  ├─ testthat/...   # R 测试
│  └─ test_*.py      # Python pytest

# 常用命令（一步步）

1. 新项目目录：
mkdir -p ~/projects/myproject
cd ~/projects/myproject
2. 生成 gen-env.R（示例）：
# gen-env.R
library(rix)

rix(
  date = "2025-09-29",            # 从 available_dates() 里选可用的日期
  r_pkgs = c("languageserver","tidyverse","testthat","reticulate"), # reticulate 可选
  py_conf = list(py_version="3.13", py_pkgs=c("numpy","pytest")),
  ide = "none",
  project_path = ".",
  overwrite = TRUE,
  print = TRUE
)


3. 生成 default.nix（第一次执行 rix）：

# 使用临时 shell 含 R 與 rix 来执行 gen-env.R
nix-shell -p R rPackages.rix --run "Rscript -e 'library(rix); source(\"gen-env.R\")'"


说明：如果报 “The provided date is not available” → 先用 available_dates() 查可用日期。

4. 添加 .envrc 并允许 direnv：

cat > .envrc <<'EOF'
use nix
mkdir -p "${TMP:-$HOME/.cache/tmp}"
EOF

direnv allow


5. 进入项目（direnv 会自动激活）：

cd ~/projects/myproject
# 或手动
nix-shell


6. 检查解释器路径（确认来自 /nix/store）：

which R
which python3

# 运行测试（在 Nix 环境中）

R (testthat)：

# 在项目根
Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'


Python (pytest)（确保用项目的 python）：

# 推荐用当前 python 运行 pytest，保证使用 Nix 的 site-packages
python3 -m pytest -q
# 若模块导入问题，可临时：
PYTHONPATH=. python3 -m pytest -q

# 常见易错点（Nix / rix）

date 必须是 YYYY-MM-DD 且存在于 available_dates() 列表；不要写 <2025-09-29> 这样的尖括号。

如果 cachix use rstats-on-nix 报权限问题，需要把用户加入 /etc/nix/nix.conf 的 trusted-users 并重启 nix-daemon。

nix-shell -p R rPackages.rix 是用来临时获得 rix，用于第一次生成 default.nix。之后进入项目应直接 nix-shell（使用项目的 default.nix）或依赖 direnv。

若遇到 R 崩溃（segfault）或包加载失败，可能是 snapshot 不兼容：换一个 date 重试。

.RData：R 退出时保存的工作区，位于项目根，建议不要依赖它。删除：rm -f .RData。

## Git & GitHub（从 0 到协作）
# 本地仓库初始化（一次性）
cd ~/projects/myproject
git init
git add .
git commit -m "Initial commit"

# 远程仓库（GitHub）

1. 在 GitHub 上新建仓库（不要勾选初始化 README）。

2. 把远程添加到本地：

git remote add origin git@github.com:youruser/myproject.git
# 或 HTTPS: https://github.com/youruser/myproject.git


3. 推送主分支：

git branch -M main
git push -u origin main


注意：GitHub 不支持通过账号密码做 Git 推送，使用 SSH key 或 Personal Access Token (PAT)。

# SSH 多账号 / 新 key（常见）

列出已有 key：

ls -la ~/.ssh


生成新 key（不覆盖现有）：

ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519_work


在 ~/.ssh/config 中添加 host 别名：

Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_work


远程用别名：

git remote set-url origin git@github-work:youruser/myproject.git

# 常用协作命令（分支工作流）
# 新分支
git checkout -b feature/add-utils

# 检查修改
git status
git diff

# 暂存并提交
git add path/to/file
git commit -m "Add normalize function"

# 推送新分支
git push -u origin feature/add-utils

# 同步 main
git fetch origin
git checkout main
git pull origin main

# 合并、解决冲突后 push
git checkout feature/add-utils
git rebase main   # 或 merge
git push

# 回滚 / 恢复常用命令
# 取消最近一次 commit（保留工作区）
git reset --soft HEAD~1

# 丢弃最近一次 commit 与改动（慎用）
git reset --hard HEAD~1

# 恢复单个文件到最后一次提交状态
git restore path/to/file  # 或 git checkout -- path/to/file

# 查看历史
git log --oneline --graph --decorate

# 小提示（易错点）

在合并或 rebase 时若遇冲突，手动编辑冲突文件 → git add 文件 → git rebase --continue 或 git commit。

提交前用 git status 和 git diff --staged 检查变动。

把不必要文件加入 .gitignore（例如 /result、/nix、.Rhistory、.RData、/.Rproj.user、__pycache__、.venv）。

示例 .gitignore（项目根）：

# R
.Rhistory
.RData
.Rproj.user

# Python
__pycache__/
*.py[cod]
.venv/

# nix
/nix/
result

## 在 Nix 环境中运行测试的完整一键流程（示例）

下面是一整套从创建环境到运行测试的命令（复制到项目根执行）：

# 1. 生成 gen-env.R（已写好）
# 2. 生成 default.nix 用 rix（只需第一次）
nix-shell -p R rPackages.rix --run "Rscript -e 'library(rix); source(\"gen-env.R\")'"

# 3. 允许 direnv 自动加载（一次性配置）
echo 'use nix' > .envrc && direnv allow

# 4. 激活环境并确认解释器
cd ~/projects/myproject
which R
which python3

# 5. 运行 R 测试
Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'

# 6. 运行 Python 测试（确保使用 Nix python）
python3 -m pytest -q
# 如遇导入问题：
PYTHONPATH=. python3 -m pytest -q

# 常见问题与排查提示（快速索引）

The provided date is not available → 用 available_dates() 查可用日期并替换 gen-env.R 的 date。

R segfault / library(...) 崩溃 → 尝试换 date，或先只用最小包测试 library(rix)，检查 nixpkgs 是否有兼容包。

which python3 显示系统路径 → 说明你没激活项目的 default.nix（用 nix-shell 或 direnv allow）。

pytest 找不到模块 utils → 在项目根运行 python3 -m pytest 或 PYTHONPATH=. python3 -m pytest，或者在测试顶部 sys.path.insert(0, ...)。

pytest 报 numpy not found → 确认 python3 -c "import numpy" 在当前解释器下可用；优先用 python3 -m pytest。

git push 认证失败 → 使用 SSH key 或 PAT；若有多个 GitHub 账号，使用 ~/.ssh/config 配置 Host 别名。

direnv 报 mkdir: missing operand → .envrc 写的 mkdir 语句格式错误，确保 mkdir -p "$TMP" 或类似写法。

# 其它可选方法 / 进阶建议

把 Python 代码放到 package (src/yourpkg/) 并做 pip install -e .，可以避免测试导入问题并利于 CI。

在项目加入 GitHub Actions：在每次 push/PR 自动运行 Nix 构建与 R/Python 测试（我可以帮你生成 workflow）。

若你想完全放弃系统 R/Python，把 ide = "positron" 或 ide = "vscode" 放进 rix 配置让 IDE 也由 Nix 管理（但可能会遇到包兼容性问题，需要调试）。
