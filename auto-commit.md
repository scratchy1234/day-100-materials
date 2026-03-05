# /commit — 智能提交技能

当被调用时，按以下步骤执行 git 提交并通过 PR 推送到主分支，**不要跳步，不要使用 `git add -A`**。

## 前置条件
- `~/.baoyu-skills/.env` 中需有 `GITHUB_TOKEN`（repo 权限）
- 从 git remote 自动读取 owner/repo，无需硬编码

## 执行步骤

### 第一步：加载环境变量 & 查看变更

> ⚠️ 必须用 `set -a` 才能让 Python 子进程继承环境变量

```bash
set -a; source ~/.baoyu-skills/.env; set +a

git status --short
git diff --stat
```

### 第二步：按主题分组
根据路径判断变更类型：

| 路径模式 | 主题标签 | 分支关键词 |
|---------|---------|-----------|
| `articles/` | 文章 | `articles` |
| `illustrations/` | 配图 | `illustrations` |
| `cover-image/` | 封面 | `cover` |
| `.claude/skills/` | 技能 | `skills` |
| `.claude/hooks/` | 钩子配置 | `hooks` |
| `.claude/settings*.json` | 项目配置 | `config` |
| 其他 | 杂项 | `misc` |

### 第三步：决定提交策略
- **单一主题**：一个 feature branch，一次提交，一个 PR
- **多个主题**：同一个 feature branch，按主题逐一提交，最终一个 PR

### 第四步：生成 branch 名和中文 commit message

**Branch 名格式**：`claude/MMDD-HHMM-关键词`（如 `claude/0305-1430-articles`）

```bash
BRANCH="claude/$(date +%m%d-%H%M)-关键词"
```

**Commit message 格式**：`动词 + 主题`

| 场景 | 动词 |
|------|------|
| 新内容 | 添加 |
| 修改润色 | 更新 |
| 修 bug | 修复 |
| 删除文件 | 删除 |
| 配置改动 | 配置 |

### 第五步：创建 feature branch 并提交

```bash
# 解析 REPO_PATH 供后续 push/pull 使用（带 token 认证）
REMOTE_URL=$(git remote get-url origin)
REPO_PATH=$(echo "$REMOTE_URL" | sed 's|https://github.com/||')
REPO_FULL=$(echo "$REPO_PATH" | sed 's|\.git$||')
AUTH_REMOTE="https://$GITHUB_TOKEN@github.com/$REPO_PATH"

# 从 main 创建分支
git checkout -b $BRANCH

# 明确指定文件，禁止使用 git add -A 或 git add .
git add articles/xxx.md illustrations/xxx/
git commit -m "添加 Day 4 文章及配图"

# 多主题时继续追加提交（同一分支）
git add .claude/hooks/xxx
git commit -m "更新 hook 配置"

# 推送分支（用 token 认证，不用 origin）
git push "$AUTH_REMOTE" "$BRANCH"
```

### 第六步：创建 PR（用 Python urllib，避免 curl JSON 转义问题）

```bash
PR_TITLE=$(git log --oneline -1 | cut -d' ' -f2-)

python3 - <<PYEOF
import json, urllib.request, os

token = os.environ['GITHUB_TOKEN']
repo = "$REPO_FULL"
branch = "$BRANCH"
title = "$PR_TITLE"

payload = json.dumps({
    "title": title,
    "head": branch,
    "base": "main",
    "body": f"由 Claude Code 自动提交\n\n分支：\`{branch}\`"
}).encode()

req = urllib.request.Request(
    f"https://api.github.com/repos/{repo}/pulls",
    data=payload,
    headers={
        "Authorization": f"token {token}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.github+json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
        print(f"PR_NUMBER={data['number']}")
        print(f"PR_URL={data['html_url']}")
except urllib.error.HTTPError as e:
    body = json.loads(e.read())
    print(f"ERROR: {body.get('message')}")
PYEOF
```

将输出的 `PR_NUMBER` 和 `PR_URL` 存入 shell 变量供下一步使用。

### 第七步：立即合并 PR

```bash
python3 - <<PYEOF
import json, urllib.request, os

token = os.environ['GITHUB_TOKEN']
repo = "$REPO_FULL"
pr_number = $PR_NUMBER
pr_title = "$PR_TITLE"

payload = json.dumps({
    "merge_method": "merge",
    "commit_title": f"Merge: {pr_title}"
}).encode()

req = urllib.request.Request(
    f"https://api.github.com/repos/{repo}/pulls/{pr_number}/merge",
    data=payload,
    headers={
        "Authorization": f"token {token}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.github+json"
    },
    method="PUT"
)

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
        print("✅ PR 已合并到 main" if data.get("merged") else f"⚠️ {data}")
except urllib.error.HTTPError as e:
    body = json.loads(e.read())
    print(f"❌ 合并失败：{body.get('message')}")
PYEOF
```

### 第八步：切回 main，同步，清理本地分支

```bash
git checkout main
git pull "$AUTH_REMOTE" main
git branch -d "$BRANCH"
```

### 第九步：确认结果并输出 PR 链接

```bash
git log --oneline -3
echo "🔗 PR 记录：$PR_URL"
```

## 排除规则（永远不提交）
- `*.bak-*` 备份文件
- `.DS_Store`
- `node_modules/`
- `*.tmp`、`*.log`

## 注意
- 遇到 hook 拦截（`stop_hook_active` 场景）时正常提交即可，下次 Stop 会自动放行
- 如果工作区干净，直接告知用户「没有需要提交的变更」
- 提交完成后务必输出 PR URL，方便用户随时回溯
