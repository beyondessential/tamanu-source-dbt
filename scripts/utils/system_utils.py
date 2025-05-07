import subprocess
import sys


def execute_command(command):
    try:
        print(f"\nRunning: {command}\n")
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as err:
        print(f"Error while running command: {command}")
        sys.exit(1)
