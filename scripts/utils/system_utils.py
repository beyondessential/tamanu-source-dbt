import subprocess
import sys


def execute_command(command):
    try:
        print(f"\nRunning: {command}\n")
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as err:
        print(f"Error while running command: {command}")
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
