import os
import re
import ast
import json
import subprocess
import shutil
from config_utils import get_lingo_prefix, get_locales, get_project_root
from print_utils import print_step, print_info, print_success, print_error

def ensure_temp_dir():
    temp_dir = os.path.join('build', 'localizations', 'lingo_to_arb')
    os.makedirs(temp_dir, exist_ok=True)
    return temp_dir

def check_lingo_installed():
    """检查 lingo-sync 目录下是否安装了 lingo CLI"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    lingo_sync_dir = os.path.join(parent_dir, 'lingo-sync')
    node_modules_lingo = os.path.join(lingo_sync_dir, 'node_modules', '.bin', 'lingo')
    
    print_info(f"检查 lingo CLI 路径: {node_modules_lingo}")
    
    if os.path.exists(node_modules_lingo) and os.access(node_modules_lingo, os.X_OK):
        print_success("检测到 lingo-sync 目录下的 lingo CLI")
        return True
    
    print_info("lingo CLI 文件不存在或不可执行")
    return False

def install_lingo_cli():
    """在 lingo-sync 目录下安装 lingo CLI"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    lingo_sync_dir = os.path.join(parent_dir, 'lingo-sync')
    
    print_info("正在检查 lingo-sync 目录...")
    if not os.path.exists(lingo_sync_dir):
        print_error(f"lingo-sync 目录不存在: {lingo_sync_dir}")
        exit(1)
    
    print_info("正在安装 lingo CLI...")
    try:
        subprocess.run(['npm', 'install'], cwd=lingo_sync_dir, check=True)
        print_success("lingo CLI 安装成功")
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"安装 lingo CLI 失败: {e}")
        return False

def ensure_lingo_available():
    """确保 lingo CLI 可用，如果不可用则尝试安装"""
    if check_lingo_installed():
        return True
    
    print_info("未检测到 lingo CLI，正在尝试安装...")
    if install_lingo_cli():
        if check_lingo_installed():
            return True
    
    print_error("无法安装或找到 lingo CLI，请手动安装：")
    print_error("在 lingo-sync 目录下运行: npm install")
    exit(1)

def run_lingo_command():
    # 确保 lingo CLI 可用
    ensure_lingo_available()
    
    # 获取脚本文件所在目录的上级目录，然后找到 lingo-sync 文件夹
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    lingo_sync_dir = os.path.join(parent_dir, 'lingo-sync')
    node_modules_lingo = os.path.join(lingo_sync_dir, 'node_modules', '.bin', 'lingo')
    
    print_info("正在执行 lingo 命令...")
    try:
        # 使用完整路径执行 lingo 命令
        subprocess.run([node_modules_lingo], cwd=lingo_sync_dir, check=True)
        print_success("Lingo 命令执行成功")
    except subprocess.CalledProcessError as e:
        print_error(f"执行 Lingo 命令失败: {e}")
        exit(1)

def process_locale_file(file_path, language, temp_dir, prefix):
    # 读取JS文件内容
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 匹配 let json = { ... } export default json
    match = re.search(r'let json = (\{[\s\S]*?\})\s*export default json', content)
    if not match:
        print_error(f"无法在文件 {file_path} 中找到JSON对象")
        return
    
    obj_str = match.group(1)
    
    # 保存所有URL
    urls = {}
    url_count = 0
    def save_url(match):
        nonlocal url_count
        url = match.group(0)
        placeholder = f"__URL_PLACEHOLDER_{url_count}__"
        urls[placeholder] = url
        url_count += 1
        return placeholder

    # 临时替换URL
    obj_str = re.sub(r'"https?://[^"]*"', save_url, obj_str)
    
    # 清理JS对象字符串，使其成为有效的JSON
    obj_str = re.sub(r'//.*?\n', '\n', obj_str)  # 移除注释
    obj_str = re.sub(r',\s*}', '}', obj_str)     # 兼容尾逗号
    obj_str = re.sub(r',\s*]', ']', obj_str)     # 移除数组中的尾随逗号
    
    # 还原URL
    for placeholder, url in urls.items():
        obj_str = obj_str.replace(placeholder, url)
    
    try:
        # 将JS对象转换为Python字典
        data = ast.literal_eval(obj_str)
    except Exception as e:
        print_error(f"解析JS对象时出错 {file_path}: {e}")
        print_error(f"问题字符串: {obj_str}")
        return
    
    # 用prefix筛选
    filtered_data = {}
    for key, value in data.items():
        if key.startswith(prefix):
            # 移除前缀
            new_key = key[len(prefix):]
            filtered_data[new_key] = value
    
    # 添加locale信息
    result = {
        "@@locale": language,
        **filtered_data
    }
    
    return result

def convert_and_copy_files(temp_dir):
    # 转换 zh_CN 到 zh_Hans_CN
    zh_cn_path = os.path.join(temp_dir, 'intl_zh_CN.arb')
    if os.path.exists(zh_cn_path):
        with open(zh_cn_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data['@@locale'] = 'zh_Hans_CN'
        with open(os.path.join(temp_dir, 'intl_zh_Hans_CN.arb'), 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        # 删除原始文件
        os.remove(zh_cn_path)
        print_info("已删除 intl_zh_CN.arb")
    
    # 转换 zh_HK 到 zh_Hant_HK 和 zh_Hant_TW
    zh_hk_path = os.path.join(temp_dir, 'intl_zh_HK.arb')
    if os.path.exists(zh_hk_path):
        with open(zh_hk_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 创建 zh_Hant_HK
        data_hk = data.copy()
        data_hk['@@locale'] = 'zh_Hant_HK'
        with open(os.path.join(temp_dir, 'intl_zh_Hant_HK.arb'), 'w', encoding='utf-8') as f:
            json.dump(data_hk, f, ensure_ascii=False, indent=2)
        
        # 删除原始文件
        os.remove(zh_hk_path)
        print_success("已删除 intl_zh_HK.arb")

def copy_to_translations(temp_dir):
    # 获取项目根目录
    project_root = get_project_root()
    translations_dir = os.path.join(project_root, 'assets', 'translations')
    os.makedirs(translations_dir, exist_ok=True)
    
    # 读取声明的语言列表
    try:
        declared_locales = get_locales()
        print_success(f"从 as_i18n.yaml 读取到的语言: {declared_locales}")
    except Exception as e:
        print_error(f"读取 as_i18n.yaml 文件失败: {e}")
        return
    
    # 复制指定语言的 arb 文件到目标目录
    copied_count = 0
    for filename in os.listdir(temp_dir):
        if filename.startswith('intl_') and filename.endswith('.arb'):
            # 从文件名中提取语言代码
            locale = filename.replace('intl_', '').replace('.arb', '')
            
            # 检查是否在声明的语言列表中
            if locale in declared_locales:
                shutil.copy2(
                    os.path.join(temp_dir, filename),
                    os.path.join(translations_dir, filename)
                )
                print_success(f"已拷贝 {filename} 到主项目")
                copied_count += 1
            else:
                print_info(f"跳过 {filename}，未在 as_i18n.yaml 中声明")

    print_info(f"总共拷贝了 {copied_count} 个语言文件")

def check_and_create_locale_files():
    # 获取脚本文件所在目录的上级目录，然后找到 lingo-sync 文件夹
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    locales_dir = os.path.join(parent_dir, 'lingo-sync', 'src', 'locales')
    os.makedirs(locales_dir, exist_ok=True)
    
    # 读取语言列表
    with open(os.path.join(script_dir, 'lingo_intl_list.txt'), 'r', encoding='utf-8') as f:
        required_languages = [line.strip() for line in f if line.strip()]
    
    # 检查每个语言文件是否存在
    for language in required_languages:
        js_file_path = os.path.join(locales_dir, f"{language}.js")
        if not os.path.exists(js_file_path):
            print_info(f"创建缺失的语言文件: {js_file_path}")
            # 创建空的JS文件，包含基本的导出结构
            with open(js_file_path, 'w', encoding='utf-8') as f:
                f.write('let json = {\n// lingo-start\n// lingo-end\n}\nexport default json\n')

def main():
    # 创建临时目录
    temp_dir = ensure_temp_dir()
    # 读取prefix
    prefix = get_lingo_prefix()
    # 1. 检查并创建缺失的语言文件
    check_and_create_locale_files()
    
    # 2. 运行 lingo 命令
    print_info("开始拉取灵果翻译")
    run_lingo_command()
    
    # 3. 处理语言文件
    # 获取脚本文件所在目录的上级目录，然后找到 lingo-sync 文件夹
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    locales_dir = os.path.join(parent_dir, 'lingo-sync', 'src', 'locales')
    
    # 遍历所有JS文件
    for filename in os.listdir(locales_dir):
        if filename.endswith('.js'):
            # 从文件名中提取语言代码
            language = filename.replace('.js', '')
            file_path = os.path.join(locales_dir, filename)
            result = process_locale_file(file_path, language, temp_dir, prefix)
            
            if result:
                # 写入ARB文件
                output_file = os.path.join(temp_dir, f"intl_{language}.arb")
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(result, f, ensure_ascii=False, indent=2)

    # 4. 转换和复制文件
    convert_and_copy_files(temp_dir)
    
    # 5. 复制到 translations 目录
    copy_to_translations(temp_dir)

    print_success("所有处理完成！")

if __name__ == "__main__":
    main() 