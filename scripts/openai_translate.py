import json
import os
import sys
from pathlib import Path
import openai
from colorama import Fore, Style
from config_utils import get_openai_api_key, get_project_root
from print_utils import print_step, print_info, print_success, print_error

localizations_sdk_dir = Path(__file__).parent.parent

# 设置 OpenAI API key
api_key = get_openai_api_key()
if api_key:
    openai.api_key = api_key
else:
    print_error(f"{Fore.RED}❌ 无法获取 OpenAI API key，程序退出{Style.RESET_ALL}")
    sys.exit(1)

def check_required_files(root_dir):
    """检查必要的文件是否存在"""
    diff_file = root_dir / "build" / "localizations" / "diff.json"
    prompt_file = localizations_sdk_dir / "scripts" / "prompt.txt"
    
    # 检查 diff.json
    if not diff_file.exists():
        print_error(f"{Fore.RED}❌ 找不到文件: {diff_file}{Style.RESET_ALL}")
        print_error(f"{Fore.YELLOW}💡 请先运行 make export_translations_diff 生成 diff.json{Style.RESET_ALL}")
        return False, None, None
    
    # 检查 prompt.txt
    if not prompt_file.exists():
        print_error(f"{Fore.RED}❌ 找不到文件: {prompt_file}{Style.RESET_ALL}")
        print_error(f"{Fore.YELLOW}💡 请确保 prompt.txt 文件存在于 scripts/ 目录下{Style.RESET_ALL}")
        return False, None, None
    
    # 读取 prompt.txt
    try:
        with open(prompt_file, 'r', encoding='utf-8') as f:
            prompt_content = f.read().strip()
    except Exception as e:
        print_error(f"{Fore.RED}❌ 读取 prompt.txt 失败: {str(e)}{Style.RESET_ALL}")
        return False, None, None
    
    return True, diff_file, prompt_content

def translate_text(text, prompt):
    """使用 OpenAI API 翻译文本"""
    try:
        response = openai.chat.completions.create(
            model="gpt-4",  # 使用 GPT-4 模型
            messages=[
                {
                    "role": "system", 
                    "content": prompt
                },
                {
                    "role": "user", 
                    "content": f"请将以下中文翻译成英文：\n{text}"
                }
            ],
            temperature=0.2,  # 降低温度以获得更稳定的输出
            max_tokens=1000,  # 设置最大输出长度
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print_error(f"{Fore.RED}❌ 翻译出错: {str(e)}{Style.RESET_ALL}")
        return None

def process_diff_file():
    """处理 diff.json 文件并生成英文翻译"""
    # 获取项目根目录
    root_dir = Path(get_project_root())
    output_file = root_dir / "build" / "localizations" / "diff_en_US.json"

    # 检查必要文件
    files_ok, diff_file, prompt = check_required_files(root_dir)
    if not files_ok:
        sys.exit(1)

    # 读取 diff.json
    try:
        with open(diff_file, 'r', encoding='utf-8') as f:
            diff_data = json.load(f)
    except Exception as e:
        print_error(f"{Fore.RED}❌ 读取 diff.json 失败: {str(e)}{Style.RESET_ALL}")
        sys.exit(1)

    # 创建英文翻译数据
    en_data = {}
    total_items = len(diff_data)
    
    print_info(f"{Fore.CYAN}📝 开始翻译，共 {total_items} 个项目...{Style.RESET_ALL}")
    print_info(f"{Fore.CYAN}🔧 使用 GPT-4 模型进行翻译{Style.RESET_ALL}")
    print_info(f"{Fore.CYAN}📋 使用自定义提示词进行翻译{Style.RESET_ALL}")

    # 翻译每个键值对
    for i, (key, value) in enumerate(diff_data.items(), 1):
        print_info(f"{Fore.YELLOW}🔄 正在翻译 ({i}/{total_items}): {key}{Style.RESET_ALL}")
        
        translated_value = translate_text(value, prompt)
        if translated_value:
            en_data[key] = translated_value
            print_success(f"{Fore.GREEN}✅ 翻译完成: {value} -> {translated_value}{Style.RESET_ALL}")
        else:
            print_error(f"{Fore.RED}❌ 跳过翻译: {key}{Style.RESET_ALL}")

    # 保存翻译结果
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(en_data, f, ensure_ascii=False, indent=2)
        print_success(f"{Fore.GREEN}✨ 翻译完成！结果已保存到: {output_file}{Style.RESET_ALL}")
    except Exception as e:
        print_error(f"{Fore.RED}❌ 保存文件失败: {str(e)}{Style.RESET_ALL}")
        sys.exit(1)

if __name__ == "__main__":
    process_diff_file() 