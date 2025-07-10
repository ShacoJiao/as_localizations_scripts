"""
配置工具模块
提供项目根目录查找和as_i18n.yaml配置读取功能
"""

import os
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any


def find_project_root() -> str:
    """
    查找包含 as_i18n.yaml 文件的主项目根目录
    
    Returns:
        str: 项目根目录的绝对路径
        
    Raises:
        FileNotFoundError: 如果找不到 as_i18n.yaml 文件
    """
    current_path = Path(__file__).resolve()
    
    # 从当前文件位置开始向上查找，直到找到 as_i18n.yaml 文件
    while current_path.parent != current_path:  # 还没到达根目录
        if (current_path / "as_i18n.yaml").exists():
            return str(current_path)
        current_path = current_path.parent
    
    # 如果没找到，使用原来的逻辑作为后备
    fallback_root = str(Path(__file__).parent.parent.parent)
    print(f"警告: 未找到 as_i18n.yaml 文件，使用后备路径: {fallback_root}")
    return fallback_root


def load_as_i18n_config() -> Dict[str, Any]:
    """
    加载 as_i18n.yaml 配置文件
    
    Returns:
        Dict[str, Any]: 配置字典
        
    Raises:
        FileNotFoundError: 如果找不到 as_i18n.yaml 文件
        yaml.YAMLError: 如果YAML格式错误
    """
    project_root = find_project_root()
    config_path = os.path.join(project_root, 'as_i18n.yaml')
    
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"未找到 as_i18n.yaml 文件: {config_path}")
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    return config


def get_locales() -> List[str]:
    """
    从 as_i18n.yaml 文件中获取支持的语言列表
    
    Returns:
        List[str]: 语言代码列表
        
    Raises:
        KeyError: 如果配置中没有 locales 字段
    """
    config = load_as_i18n_config()
    
    if 'locales' not in config:
        raise KeyError("在 as_i18n.yaml 中找不到 locales 配置")
    
    return config['locales']


def get_lingo_config() -> Dict[str, Any]:
    """
    从 as_i18n.yaml 文件中获取 lingo 配置
    
    Returns:
        Dict[str, Any]: lingo 配置字典
        
    Raises:
        KeyError: 如果配置中没有 lingo 字段
    """
    config = load_as_i18n_config()
    
    if 'lingo' not in config:
        raise KeyError("在 as_i18n.yaml 中找不到 lingo 配置")
    
    return config['lingo']


def get_lingo_prefix() -> str:
    """
    从 as_i18n.yaml 文件中获取 lingo prefix
    
    Returns:
        str: lingo prefix，如果不存在则返回空字符串
    """
    try:
        lingo_config = get_lingo_config()
        return lingo_config.get('prefix', '')
    except KeyError:
        return ''


def get_openai_api_key() -> str:
    """
    从 as_i18n.yaml 文件中获取 OpenAI API key
    
    Returns:
        str: OpenAI API key
        
    Raises:
        KeyError: 如果配置中没有 openai-api-key 字段
    """
    config = load_as_i18n_config()
    
    if 'openai-api-key' not in config:
        raise KeyError("在 as_i18n.yaml 中找不到 openai-api-key 配置")
    
    return config['openai-api-key']


def get_feature_strings() -> Dict[str, str]:
    """
    从 as_i18n.yaml 文件中获取 feature-strings 配置
    
    Returns:
        Dict[str, str]: feature-strings 配置字典
        
    Raises:
        KeyError: 如果配置中没有 feature-strings 字段
    """
    config = load_as_i18n_config()
    
    if 'feature-strings' not in config:
        raise KeyError("在 as_i18n.yaml 中找不到 feature-strings 配置")
    
    return config['feature-strings']


def get_i18n_dir() -> str:
    """
    从 as_i18n.yaml 文件中获取 i18n-dir 配置
    
    Returns:
        str: i18n-dir 路径，默认为 'lib/localizations/'
    """
    config = load_as_i18n_config()
    return config.get('i18n-dir', 'lib/localizations/')


def get_template_json_file() -> str:
    """
    从 as_i18n.yaml 文件中获取 template-json-file 配置
    
    Returns:
        str: template-json-file 文件名，默认为 'as_i18n.json'
    """
    config = load_as_i18n_config()
    return config.get('template-json-file', 'as_i18n.json')


def get_output_localization_file() -> str:
    """
    从 as_i18n.yaml 文件中获取 output-localization-file 配置
    
    Returns:
        str: output-localization-file 文件名，默认为 'app_localizations.dart'
    """
    config = load_as_i18n_config()
    return config.get('output-localization-file', 'app_localizations.dart')


# 便捷函数：获取项目根目录
def get_project_root() -> str:
    """
    获取项目根目录
    
    Returns:
        str: 项目根目录的绝对路径
    """
    return find_project_root()


# 便捷函数：获取配置文件的完整路径
def get_config_path() -> str:
    """
    获取 as_i18n.yaml 配置文件的完整路径
    
    Returns:
        str: 配置文件的完整路径
    """
    project_root = find_project_root()
    return os.path.join(project_root, 'as_i18n.yaml') 