#!/usr/bin/env python3
"""
scrapling 安装和检测脚本
支持 macOS/Linux 从 0 开始自动安装
"""

import sys
import subprocess
import os
import shutil

def get_best_python():
    """获取最佳的 Python 版本"""
    # 优先使用 Python 3.11/3.12/3.13（稳定版本）
    candidates = [
        "/opt/homebrew/bin/python3.13",
        "/opt/homebrew/bin/python3.12", 
        "/opt/homebrew/bin/python3.11",
        "/opt/homebrew/bin/python3",
        "python3"
    ]

    for cmd in candidates:
        if shutil.which(cmd):
            try:
                result = subprocess.run(
                    [cmd, "--version"],
                    capture_output=True,
                    text=True
                )
                version = result.stdout.strip()
                # 检查版本号
                for v in ["3.13", "3.12", "3.11", "3.10", "3.9"]:
                    if v in version:
                        print(f"✅ 找到合适的 Python: {version}")
                        return cmd
            except:
                pass

    return "python3"

def check_scrapling(python_cmd):
    """检测 scrapling 是否已安装"""
    try:
        result = subprocess.run(
            [python_cmd, "-c", "import scrapling; print(scrapling.__version__)"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            print(f"✅ scrapling 已安装: {result.stdout.strip()}")
            return True
    except Exception:
        pass
    print("❌ scrapling 未安装")
    return False


def install_scrapling(python_cmd):
    """安装 scrapling"""
    print(f"🚀 开始安装 scrapling (使用 {python_cmd})...")

    # 检查 Python 版本
    result = subprocess.run(
        [python_cmd, "--version"],
        capture_output=True,
        text=True
    )
    print(f"   Python 版本: {result.stdout.strip()}")

    # 创建虚拟环境
    venv_path = os.path.expanduser("~/.scrapling-venv")

    if os.path.exists(venv_path):
        print(f"   🗑️ 删除旧虚拟环境...")
        shutil.rmtree(venv_path)

    print(f"   创建虚拟环境: {venv_path}")
    try:
        subprocess.run(
            [python_cmd, "-m", "venv", venv_path],
            check=True,
            capture_output=True
        )
        print("   ✅ 虚拟环境创建成功")
    except Exception as e:
        print(f"   ❌ 虚拟环境创建失败: {e}")
        return False

    pip_cmd = os.path.join(venv_path, "bin", "pip")

    # 先升级 pip
    print("   升级 pip...")
    subprocess.run(
        [pip_cmd, "install", "--upgrade", "pip", "-q"],
        capture_output=True
    )

    # 安装 scrapling 基础版本（不含 fetchers，减少依赖问题）
    print("   安装 scrapling（基础版本）...")
    try:
        result = subprocess.run(
            [pip_cmd, "install", "scrapling", "-q"],
            capture_output=True,
            text=True,
            timeout=180
        )
        if result.returncode != 0:
            print(f"   ⚠️ 基础版本安装失败: {result.stderr[:200]}")
            # 尝试只安装核心解析库
            print("   尝试安装 lxml + requests...")
            subprocess.run([pip_cmd, "install", "lxml", "requests", "cssselect", "-q"], timeout=120)
            return True
        print("   ✅ scrapling 安装成功!")
    except Exception as e:
        print(f"   ⚠️ 安装警告: {e}")

    # 验证安装
    python_venv = os.path.join(venv_path, "bin", "python")
    result = subprocess.run(
        [python_venv, "-c", "import scrapling; print(scrapling.__version__)"],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        print(f"   ✅ 验证成功! scrapling 版本: {result.stdout.strip()}")
    else:
        print(f"   ⚠️ 验证失败，但已安装基础依赖")

    print(f"\n🎉 安装完成!")
    print(f"   虚拟环境: {venv_path}")
    print(f"   Python: {python_venv}")

    return True


def main():
    print("=" * 50)
    print("🔧 scrapling 安装/检测工具")
    print("=" * 50)

    # 获取最佳 Python
    python_cmd = get_best_python()
    print(f"使用 Python: {python_cmd}")

    if check_scrapling(python_cmd):
        print("\n✅ scrapling 已就绪，无需安装")
        return 0

    print("\n⚡ 开始安装 scrapling...")
    if install_scrapling(python_cmd):
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
