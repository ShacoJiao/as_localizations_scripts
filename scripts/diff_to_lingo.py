import os
import json
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
from config_utils import get_project_root
project_root = get_project_root()
if project_root not in sys.path:
    sys.path.append(project_root)

from print_utils import print_step, print_info, print_success, print_error
from config_utils import get_locales

def read_supported_languages():
    """从 as_i18n.yaml 文件的 locales 字段读取支持的语言列表"""
    try:
        # 获取 locales 配置
        locales = get_locales()
        
        # 语言代码映射关系（只处理需要映射的语言）
        locale_mapping = {
            'zh_Hans_CN': 'zh_CN',
            'zh_Hant_HK': 'zh_HK'
        }
        
        # 转换语言代码
        supported_languages = []
        for locale in locales:
            if locale in locale_mapping:
                supported_languages.append(locale_mapping[locale])
            else:
                # 其他语言代码直接使用原值
                supported_languages.append(locale)
        
        # 确保 en_US 始终存在
        if 'en_US' not in supported_languages:
            supported_languages.append('en_US')
        
        # 去重并排序
        supported_languages = sorted(list(set(supported_languages)))
        
        print_info(f"从 as_i18n.yaml 读取到 {len(locales)} 个语言配置")
        print_info(f"转换后得到 {len(supported_languages)} 种支持的语言: {', '.join(supported_languages)}")
        return supported_languages
    except Exception as e:
        print_error(f"读取语言配置时出错: {e}")
        sys.exit(1)

def read_diff_json():
    """读取 diff.json 和 diff_en_US.json 文件"""
    try:
        # 使用项目根目录的绝对路径
        diff_path = os.path.join(project_root, 'build', 'localizations', 'diff.json')
        if not os.path.exists(diff_path):
            print_error(f"找不到 diff.json 文件: {diff_path}")
            print_info("请先运行 make export_translations_diff 生成 diff.json 文件")
            sys.exit(1)

        with open(diff_path, 'r', encoding='utf-8') as f:
            content = f.read().strip()
            if not content:
                print_error("diff.json 文件为空")
                print_info("请先运行 make export_translations_diff 生成 diff.json 文件")
                sys.exit(1)
            zh_data = json.loads(content)

        # 读取英文翻译
        en_diff_path = os.path.join(project_root, 'build', 'localizations', 'diff_en_US.json')
        if not os.path.exists(en_diff_path):
            print_error(f"找不到 diff_en_US.json 文件: {en_diff_path}")
            print_info("请先翻译英文并生成 diff_en_US.json 文件")
            sys.exit(1)

        with open(en_diff_path, 'r', encoding='utf-8') as f:
            content = f.read().strip()
            if not content:
                print_error("diff_en_US.json 文件为空")
                print_info("请先翻译英文并生成 diff_en_US.json 文件")
                sys.exit(1)
            en_data = json.loads(content)

        return zh_data, en_data
    except json.JSONDecodeError:
        print_error("JSON 文件格式错误")
        sys.exit(1)
    except Exception as e:
        print_error(f"读取文件时出错: {e}")
        sys.exit(1)

def convert_to_lingo_format(zh_data, en_data, supported_languages):
    """将 diff.json 和 diff_en_US.json 数据转换为 lingo 格式"""
    try:
        translations = []
        
        # 遍历所有键
        for key in sorted(zh_data.keys()):
            # 创建新的翻译项
            translation_item = {
                "key": key,
                "zh_CN": zh_data[key],  # 从 diff.json 获取中文值
                "en_US": en_data.get(key, "")  # 从 diff_en_US.json 获取英文值
            }
            
            # 为其他语言添加空字符串
            for lang in supported_languages:
                if lang not in ["zh_CN", "en_US"]:
                    translation_item[lang] = ""
            
            translations.append(translation_item)
        
        return translations
    except Exception as e:
        print_error(f"转换数据时出错: {e}")
        sys.exit(1)

def save_translations(translations):
    """保存转换后的数据"""
    try:
        # 使用项目根目录的绝对路径
        output_dir = os.path.join(project_root, 'build', 'localizations')
        os.makedirs(output_dir, exist_ok=True)
        
        # 保存文件
        output_path = os.path.join(output_dir, 'new_to_lingo.json')
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(translations, f, ensure_ascii=False, indent=2)
            f.write('\n')  # 添加最后的换行符
        
        print_success(f"转换后的文件已保存到: {output_path}")
        print_info(f"总共转换了 {len(translations)} 个键值对")
    except Exception as e:
        print_error(f"保存文件时出错: {e}")
        sys.exit(1)

def main():
    try:
        print_step("开始", "开始转换翻译文件")
        
        # 读取支持的语言列表
        print_info("读取支持的语言列表...")
        supported_languages = read_supported_languages()
        
        # 读取翻译文件
        print_info("读取翻译文件...")
        zh_data, en_data = read_diff_json()
        
        # 转换数据
        print_info("转换数据格式...")
        translations = convert_to_lingo_format(zh_data, en_data, supported_languages)
        
        # 保存结果
        print_info("保存转换后的数据...")
        save_translations(translations)
        
        print_success("转换完成")
    except Exception as e:
        print_error(f"执行过程中出错: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 