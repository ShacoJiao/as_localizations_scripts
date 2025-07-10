import os
import re
import ast
import json
import subprocess
import shutil
from config_utils import get_lingo_prefix, get_locales, get_project_root, get_feature_strings, get_i18n_dir, get_template_json_file
from print_utils import print_step, print_info, print_success, print_error

def create_missing_language_files():
    """创建缺失的语言文件"""
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

def load_arb_file(arb_file_path):
    """加载ARB文件并返回键值对字典"""
    if not os.path.exists(arb_file_path):
        print_error(f"ARB文件不存在: {arb_file_path}")
        return {}
    
    try:
        with open(arb_file_path, 'r', encoding='utf-8') as f:
            arb_data = json.load(f)
        
        # 过滤掉以@开头的元数据键
        translations = {}
        for key, value in arb_data.items():
            if not key.startswith('@'):
                translations[key] = value
        
        return translations
    except Exception as e:
        print_error(f"读取ARB文件失败: {e}")
        return {}

def load_template_json(template_file_path):
    """加载模板JSON文件并返回键值对字典"""
    if not os.path.exists(template_file_path):
        print_error(f"模板JSON文件不存在: {template_file_path}")
        return {}
    
    try:
        with open(template_file_path, 'r', encoding='utf-8') as f:
            template_data = json.load(f)
        return template_data
    except Exception as e:
        print_error(f"读取模板JSON文件失败: {e}")
        return {}

def save_template_json(template_file_path, data):
    """保存模板JSON文件"""
    try:
        with open(template_file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print_success(f"已更新模板JSON文件: {template_file_path}")
    except Exception as e:
        print_error(f"保存模板JSON文件失败: {e}")

def should_add_key(key, feature_strings):
    """判断是否应该添加这个键到模板JSON中"""
    for feature_key, feature_prefix in feature_strings.items():
        # 将feature_strings中的值转换为ARB文件中的前缀格式
        # 例如：app_strings -> appstrings_
        arb_prefix = feature_prefix.replace('_', '') + '_'
        if key.startswith(arb_prefix):
            return True
    return False

def main():
    print_step("COMPARE", "开始比较ARB文件和模板JSON文件")
    
    # 1. 获取项目根目录中的assets/translations/intl_zh_Hans_CN.arb文件
    project_root = get_project_root()
    arb_file_path = os.path.join(project_root, 'assets', 'translations', 'intl_zh_Hans_CN.arb')
    
    # 2. 读取config_utils配置中的 i18n-dir、template-json-file、feature-strings
    i18n_dir = get_i18n_dir()
    template_json_file = get_template_json_file()
    feature_strings = get_feature_strings()
    
    template_file_path = os.path.join(project_root, i18n_dir, template_json_file)
    
    print_info(f"ARB文件路径: {arb_file_path}")
    print_info(f"模板JSON文件路径: {template_file_path}")
    print_info(f"功能字符串配置: {feature_strings}")
    
    # 3. 加载ARB文件和模板JSON文件
    arb_translations = load_arb_file(arb_file_path)
    template_data = load_template_json(template_file_path)
    
    if not arb_translations:
        print_error("无法加载ARB文件，退出")
        return
    
    if not template_data:
        print_error("无法加载模板JSON文件，退出")
        return
    
    print_info(f"ARB文件包含 {len(arb_translations)} 个翻译键")
    print_info(f"模板JSON文件包含 {len(template_data)} 个键")
    
    # 4. 比较并添加缺失的键值对
    added_count = 0
    for key, value in arb_translations.items():
        # 检查键是否在模板JSON中不存在
        if key not in template_data:
            # 检查键是否以feature-strings中的值为开头
            if should_add_key(key, feature_strings):
                template_data[key] = value
                added_count += 1
                print_info(f"添加新键: {key}")
    
    # 5. 保存更新后的模板JSON文件
    if added_count > 0:
        save_template_json(template_file_path, template_data)
        print_success(f"成功添加了 {added_count} 个新的翻译键到模板JSON文件中")
    else:
        print_info("没有需要添加的新翻译键")

if __name__ == "__main__":
    main() 