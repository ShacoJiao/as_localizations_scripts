import os
import re
import subprocess
import json
import sys
import glob
from pathlib import Path

# 导入配置工具模块
from config_utils import get_project_root

# 获取项目根目录
project_root = get_project_root()
if project_root not in sys.path:
    sys.path.append(project_root)

from print_utils import print_step, print_info, print_success, print_error
from colorama import init, Fore, Style

# 初始化 colorama
init()

def get_venv_python():
    """获取虚拟环境的 Python 路径"""
    venv_python = Path(project_root) / "venv" / "bin" / "python"
    if not venv_python.exists():
        print_error("找不到虚拟环境的 Python 解释器")
        sys.exit(1)
    return str(venv_python)

def ensure_output_dir():
    """确保输出目录存在"""
    output_dir = os.path.join(project_root, 'build/localizations')
    os.makedirs(output_dir, exist_ok=True)
    return output_dir

def merge_arb_files():
    try:
        # 获取所有 arb 文件
        arb_files = glob.glob(os.path.join(project_root, 'build/localizations/arb/*.arb'))
        if not arb_files:
            print_error("在 build/localizations/arb 目录下没有找到 arb 文件")
            return None

        # 合并所有 arb 文件
        merged_data = {}
        for arb_file in arb_files:
            with open(arb_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                merged_data.update(data)
        
        print_success(f"成功合并了 {len(arb_files)} 个 arb 文件")
        return merged_data
    except Exception as e:
        print_error(f"合并 arb 文件时出错: {e}")
        return None

def compare_arb_files():
    try:
        # 合并临时 arb 文件
        merged_messages = merge_arb_files()
        if not merged_messages:
            return False

        # 读取现有的中文翻译文件
        with open(os.path.join(project_root, 'assets/translations/intl_zh_Hans_CN.arb'), 'r', encoding='utf-8') as f:
            zh_cn = json.load(f)
        
        # 找出缺失的key
        missing_keys = set(merged_messages.keys()) - set(zh_cn.keys())
        
        if missing_keys:
            print_info(f"找到 {len(missing_keys)} 个缺失的翻译")
            
            # 构建diff数据
            diff_data = {}
            for key in missing_keys:
                diff_data[key] = merged_messages[key]
            
            # 确保输出目录存在
            output_dir = ensure_output_dir()
            
            # 写入diff.json
            diff_path = os.path.join(output_dir, 'diff.json')
            with open(diff_path, 'w', encoding='utf-8') as f:
                json.dump(diff_data, f, indent=2, ensure_ascii=False)
            print_success(f"已生成 diff.json 到 {diff_path}")
            return True
        else:
            print_success("没有发现缺失的翻译")
            return False
    except Exception as e:
        print_error(f"对比文件时出错: {e}")
        return False

def run_command(cmd, cwd=None):
    print_info(f"执行命令: {cmd}")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True, cwd=cwd)
        if result.stdout:
            print_info(f"命令输出: {result.stdout}")
        print_success("命令执行成功")
    except subprocess.CalledProcessError as e:
        print_error(f"命令执行失败: {e}")
        if e.stderr:
            print_error(f"错误输出: {e.stderr}")
        raise

def check_and_install_lingo(sdk_dir):
    """检查并安装 lingo-cli"""
    # 保存当前工作目录
    original_dir = os.getcwd()
    lingo_sync_dir = os.path.join(sdk_dir, "lingo-sync")
    
    try:
        # 切换到 lingo-sync 目录
        os.chdir(lingo_sync_dir)
        
        # 检查本地 lingo-cli 是否已安装
        if os.path.exists('node_modules/lingo-cli'):
            print("✅ 本地 lingo-cli 已安装")
            return
        else:
            print("📦 本地 lingo-cli 未安装，正在安装...")
            subprocess.run(['npm', 'install', 'lingo-cli'], check=True)
            print("✅ 本地 lingo-cli 安装成功！")
            
    except subprocess.CalledProcessError as e:
        print("❌ 本地 lingo-cli 安装失败！")
        print(f"错误信息: {e}")
        sys.exit(1)
    finally:
        # 确保返回原始目录
        os.chdir(original_dir)


def main():
    try:
        localizations_sdk_dir = str(Path(__file__).parent.parent)

        check_and_install_lingo(localizations_sdk_dir)
        
        # 确保输出目录存在
        output_dir = ensure_output_dir()

        os.makedirs(os.path.join(output_dir, "arb"), exist_ok=True)
        os.makedirs("assets/translations", exist_ok=True)

        print_step("Step 1", "Generate _strings.dart")
        run_command("dart run ./scripts/generate.dart", cwd=localizations_sdk_dir)

        print_step("Step 2", "Generate _strings.dart")
        run_command("dart run ./scripts/generate.dart", cwd=localizations_sdk_dir)

        print_step("Step 3", "Create not exist arb files")
        run_command("dart run ./scripts/create_not_exist_arb.dart", cwd=localizations_sdk_dir)

        print_step("Step 4", "Check Sid")
        run_command("dart run ./scripts/check_and_fix_sid.dart", cwd=localizations_sdk_dir)


        print_step("Step 5", "Generate new *_strings.dart")
        run_command("dart run ./scripts/generate_new_strings.dart", cwd=localizations_sdk_dir)

        print_step("Step 6", "Compare zh_CN ARB to diff.json")
        has_missing_translations = compare_arb_files()

        if has_missing_translations:
            print_step("Step 7", "OpenAI Translate")
            venv_python = get_venv_python()
            run_command(f"{venv_python} ./scripts/openai_translate.py", cwd=localizations_sdk_dir)
                
            print_step("Step 8", "Export lingo json file")
            run_command(f"{venv_python} ./scripts/diff_to_lingo.py", cwd=project_root)
        else:
            print_info("没有需要翻译的内容，跳过步骤 7 和 8")

    except Exception as e:
        print_error(f"执行过程中出错: {e}")
        exit(1)

if __name__ == "__main__":
    main() 