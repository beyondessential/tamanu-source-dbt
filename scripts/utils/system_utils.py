import subprocess
import sys

RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
WHITE = "\033[97m"
RESET = "\033[0m"


def cprint(message, msg_type="info"):
    """
    Print a colored message based on type: error, warning, info, success.
    Args:
        message (str): The message to print
        msg_type (str): Type of message - 'error', 'warning', 'info', 'success'
    """
    colors = {
        "error": RED,
        "warning": YELLOW,
        "info": CYAN,
        "success": GREEN,
    }
    color = colors.get(msg_type.lower(), WHITE)
    print(f"{color}{message}{RESET}")


def execute_command(command):
    """
    Execute a shell command and exit the program if it fails.
    Args:
        command (str): The shell command to execute
    """
    try:
        cprint(f"Running: {command}", "info")
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as err:
        cprint(f"Error while running command: {err}", "error")
        sys.exit(1)


def execute_command_with_output(command, cwd=None):
    """
    Execute a shell command and return the result with captured output.
    Args:
        command (str): The shell command to execute
        cwd (str, optional): Working directory to execute the command in
    Returns:
        subprocess.CompletedProcess: The result object containing stdout, stderr, and return code
    """
    try:
        return subprocess.run(
            command, cwd=cwd, capture_output=True, text=True, shell=True
        )
    except Exception as e:
        cprint(f"Error while running command: {e}", "error")
        sys.exit(1)


def get_arg_value(args, long_flag, short_flag, default_value=None):
    """
    Get argument value from either long or short flag.
    Args:
        args (list): Command line arguments
        long_flag (str): Long flag name (e.g., '--project')
        short_flag (str): Short flag name (e.g., '-p')
        default_value: Default value if neither flag is found
    Returns:
        The argument value or default_value if not found
    """
    for flag in [long_flag, short_flag]:
        if flag in args:
            index = args.index(flag) + 1
            if index < len(args):
                return args[index]
    return default_value
