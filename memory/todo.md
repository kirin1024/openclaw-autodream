# 待办事项

## 待处理

### OpenClaw 更新后测试大金主浏览器权限
- **状态**: 待完成
- **说明**: 更新 OpenClaw 到最新版本后，尝试让大金主（invest-advisor）使用 browser 工具打开网页
- **当前版本**: 2026.2.26
- **目标版本**: 2026.3.8
- **更新命令**: `openclaw update`（需要先解决 npm 缓存权限问题）

### npm 缓存权限问题
- **问题**: npm 全局更新时报错 EACCES，需要 sudo 权限
- **解决方案**: 
  - 运行 `sudo chown -R 2111601258:1974412862 "/Users/chenyan/.npm"`
  - 或者手动删除 ~/.npm 目录后重试
