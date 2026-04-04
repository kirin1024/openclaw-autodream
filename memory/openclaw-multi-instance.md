# OpenClaw 多实例架构

## 现有实例
| 实例名 | 端口 | 用途 | 飞书机器人 | 浏览器/搜索 |
|--------|------|------|-----------|------------|
| 主（kk-bot） | 18788 | 首席牛马官 | cli_a925b660977a5bd2 | ✅ |
| v-shop | 18766 | VSHOP项目经理 | cli_a94cebae0c795cb6 | ✅ |
| v-coder | 18770 | VSHOP全栈开发 | cli_a94ce3cf08395ceb | ✅ |

## Skill：新建 OpenClaw 实例
- **路径**：`~/.openclaw/workspace/skills/openclaw-new-instance/SKILL.md`
- **功能**：从主实例复制配置，快速创建新的独立OpenClaw实例
- **触发词**："新建实例"、"创建新agent"、"安装新实例"
- **重要更新（2026-03-27）**：配置已包含完整 browser + tools + commands，**新建后必须自测搜索能力**

## 新建实例操作流程（简化版）
1. `openclaw --profile <名称> setup`
2. 编写 openclaw.json（含完整配置）
3. `openclaw --profile <名称> gateway install --port <端口>`
4. `openclaw --profile <名称> gateway start`
5. 审批飞书配对
6. **自测搜索能力**（web_search + web_fetch + browser）

## 已知端口占用
- 18766（VSHOP）、18788（主）、18789（曾被占用）

## 当前版本记录
- 主 Gateway：2026.4.2（2026-04-04 从 2026.3.24 升级）
- 群消息功能：已修复，正常工作
- 已修复：memory_get tool schema 报错（400 Tool invalid parameters schema）
- 关键变更：OpenClaw 更新后工具 schema 校验通过，qiwen 可正常调度
