import subprocess
import sys


def execute_command(command):
    """
    Execute a shell command and exit the program if it fails.
    Args:
        command (str): The shell command to execute
    """
    try:
        print(f"\nRunning: {command}\n")
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as err:
        print(f"Error while running command:\n{err}\n")
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
        print(f"\nRunning: {command}\n")
        return subprocess.run(
            command, cwd=cwd, capture_output=True, text=True, shell=True
        )
    except Exception as e:
        print(f"Error while running command:\n{e}\n")
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
    if long_flag in args:
        long_index = args.index(long_flag) + 1
        if long_index < len(args):
            return args[long_index]

    if short_flag in args:
        short_index = args.index(short_flag) + 1
        if short_index < len(args):
            return args[short_index]

    return default_value
