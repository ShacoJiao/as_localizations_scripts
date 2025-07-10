import os
import json
import glob
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
from config_utils import get_project_root
project_root = get_project_root()
if project_root not in sys.path:
    sys.path.append(project_root)

from print_utils import print_step, print_info, print_success, print_error

def sort_arb_file(file_path):
    """对 ARB 文件进行排序，保持 @@locale 在第一行，其他键值对按 key 排序"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 保存 @@locale
        locale = data.pop('@@locale', None)
        
        # 创建新的有序字典
        sorted_data = {}
        if locale is not None:
            sorted_data['@@locale'] = locale
        
        # 按 key 排序并添加其他键值对
        for key in sorted(data.keys()):
            sorted_data[key] = data[key]
        
        # 写回文件
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(sorted_data, f, ensure_ascii=False, indent=2)
            f.write('\n')  # 添加最后的换行符
        
        print_success(f"文件 {os.path.basename(file_path)} 排序完成")
    except Exception as e:
        print_error(f"排序文件 {file_path} 时出错: {e}")

def sort_all_arb_files():
    """对所有 ARB 文件进行排序"""
    try:
        arb_files = glob.glob('./assets/translations/*.arb')
        if not arb_files:
            print_error("没有找到 ARB 文件")
            return

        print_info(f"开始对 {len(arb_files)} 个 ARB 文件进行排序")
        for arb_file in arb_files:
            sort_arb_file(arb_file)
        
        print_success("所有文件排序完成")
    except Exception as e:
        print_error(f"排序过程中出错: {e}")

def validate_arb_files():
    """验证所有 ARB 文件"""
    error_count = 0
    try:
        # 获取所有 arb 文件
        arb_files = glob.glob('./assets/translations/*.arb')
        if not arb_files:
            print_error("没有找到 ARB 文件")
            sys.exit(1)

        print_info(f"找到 {len(arb_files)} 个 ARB 文件")
        
        # 首先读取所有文件的内容
        file_contents = {}
        for arb_file in arb_files:
            try:
                with open(arb_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                file_contents[arb_file] = data
            except json.JSONDecodeError:
                print_error(f"文件 {arb_file} 不是有效的 JSON 格式")
                error_count += 1
            except Exception as e:
                print_error(f"读取文件 {arb_file} 时出错: {e}")
                error_count += 1

        if error_count > 0:
            print_error("文件读取阶段发现错误，停止验证")
            sys.exit(1)

        # 获取所有文件的键集合
        all_keys = set()
        for data in file_contents.values():
            all_keys.update(k for k in data.keys() if not k.startswith('@'))

        # 验证每个文件
        for arb_file, data in file_contents.items():
            print_step("验证", f"正在验证文件: {os.path.basename(arb_file)}")
            
            # 检查必要的字段
            if '@@locale' not in data:
                print_error(f"文件 {arb_file} 缺少 @@locale 字段")
                error_count += 1
                continue

            # 检查是否缺少其他文件中的键
            file_keys = set(k for k in data.keys() if not k.startswith('@'))
            missing_keys = all_keys - file_keys
            if missing_keys:
                print_error(f"文件 {arb_file} 缺少以下键:\n" + ",\n".join(sorted(missing_keys)))
                error_count += 1

            # 检查翻译键值
            for key, value in data.items():
                if key.startswith('@'):  # 跳过元数据
                    continue
                
                if not isinstance(value, str):
                    print_error(f"键 {key} 的值不是字符串类型")
                    error_count += 1
                    continue

                # 检查占位符
                if '{' in value and '}' in value:
                    # 检查占位符格式
                    import re
                    placeholders = re.findall(r'\{([^}]+)\}', value)
                    for placeholder in placeholders:
                        if not placeholder.isalnum() and not placeholder.startswith('_'):
                            print_error(f"键 {key} 包含无效的占位符: {placeholder}")
                            error_count += 1

            if error_count == 0:
                print_success(f"文件 {os.path.basename(arb_file)} 验证通过")

        if error_count > 0:
            print_error(f"验证失败：发现 {error_count} 个错误")
            sys.exit(1)
        else:
            print_success("所有文件验证通过")

    except Exception as e:
        print_error(f"验证过程中出错: {e}")
        sys.exit(1)

def main():
    try:
        print_step("开始", "开始排序翻译文件")
        sort_all_arb_files()
        print_success("排序完成")
        
        print_step("开始", "开始验证翻译文件")
        validate_arb_files()
        print_success("验证完成")
    except Exception as e:
        print_error(f"执行过程中出错: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 