import sys
import subprocess

def check_and_install_colorama():
    """检查并安装 colorama 包"""
    try:
        import colorama
    except ImportError:
        print("正在安装 colorama 包...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "colorama"])
            print("colorama 安装成功")
        except subprocess.CalledProcessError as e:
            print(f"安装 colorama 失败: {e}")
            sys.exit(1)

# 检查并安装 colorama
check_and_install_colorama()

# 现在可以安全地导入 colorama
from colorama import init, Fore, Style

# 初始化 colorama
init()

def print_step(step, message):
    """打印步骤信息"""
    print('\n')
    print(f"++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    print(f"{Fore.CYAN}[{step}]{Style.RESET_ALL} {message}")

def print_info(message):
    """打印普通信息"""
    print(f"{Fore.BLUE}[INFO]{Style.RESET_ALL} {message}")

def print_success(message):
    """打印成功信息"""
    print(f"{Fore.GREEN}[SUCCESS]{Style.RESET_ALL} {message}")

def print_error(message):
    """打印错误信息"""
    print(f"{Fore.RED}[ERROR]{Style.RESET_ALL} {message}")

def print_warning(message):
    """打印警告信息"""
    print(f"{Fore.YELLOW}[WARNING]{Style.RESET_ALL} {message}") 