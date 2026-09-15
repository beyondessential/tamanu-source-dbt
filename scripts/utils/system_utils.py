import os
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
    try:
        print(f"{color}{message}{RESET}")
    except UnicodeEncodeError:
        # Windows consoles on a non-UTF-8 codepage (e.g. cp1252) can't encode
        # some characters (emoji, smart quotes) straight to stdout. Fall back
        # to a readable escaped form rather than crashing the script.
        # backslashreplace keeps the codepoint visible (e.g. ✅) so
        # different emoji stay distinguishable in the log; errors="replace"
        # would collapse every one of them to the same "?" glyph.
        # getattr guards sys.stdout itself being None (e.g. pythonw.exe, a
        # detached process), not just .encoding being unset.
        encoding = getattr(sys.stdout, "encoding", None) or "ascii"
        safe_message = message.encode(encoding, errors="backslashreplace").decode(encoding)
        print(f"{color}{safe_message}{RESET}")


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
        # PYTHONUTF8/PYTHONIOENCODING force the *child* process (dbt, itself
        # a Python process spawned via shell=True) to write UTF-8 rather than
        # the host's console codepage (cp1252 on Windows). Without this, dbt
        # encodes survey question text containing a non-cp1252 character
        # (smart quotes, etc.) using cp1252 before we ever see it, handing us
        # a byte sequence that isn't valid UTF-8 -- our own decode below then
        # has no choice but to substitute a replacement character, silently
        # corrupting content it could have gotten right if the child had
        # written UTF-8 in the first place.
        child_env = os.environ.copy()
        child_env["PYTHONUTF8"] = "1"
        child_env["PYTHONIOENCODING"] = "utf-8"

        # encoding/errors on our own end: without it, `text=True` decodes
        # captured output using the host's preferred locale encoding instead
        # of UTF-8. A byte sequence the target encoding can't decode then
        # raises UnicodeDecodeError inside a subprocess reader thread --
        # non-deterministically either crashing the read (leaving
        # stdout/stderr as None, which callers combine with `+` and get a
        # TypeError) or hanging. UTF-8 decodes correctly once the child
        # writes UTF-8 (see above); errors="replace" is a last-resort
        # backstop against any residual invalid bytes, never raising.
        return subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            shell=True,
            encoding="utf-8",
            errors="replace",
            env=child_env,
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
