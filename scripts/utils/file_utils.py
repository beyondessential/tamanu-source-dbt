import json
import os
import shutil
import stat
from pathlib import Path

import boto3
import pandas as pd

from .system_utils import cprint


def ensure_file_exists(file_path):
    """
    Ensures that the file at the given path exists.

    Args:
        file_path (str): The path to the file to check.

    Exits the program if the file does not exist.
    """
    if not os.path.isfile(file_path):
        cprint(f"Error: File not found: {file_path}", "error")
        exit(1)


def read_file(file_path, file_type="text"):
    """
    Reads the contents of a file at the given path.

    Args:
        file_path (str): The path to the file to read.
        file_type (str): The type of the file ('text', 'json', or 'excel'/'xlsx'). Defaults to 'text'.

    Returns:
        str, dict, or DataFrame: The file content as a string (for text files), a dictionary
            (for JSON files), or a pandas DataFrame (for Excel files).

    Raises:
        FileNotFoundError: If the file does not exist.
        ValueError: If the file_type is not supported.
        Exception: For other errors during reading or parsing.
    """
    try:
        ensure_file_exists(file_path)
        if file_type == "json":
            with open(file_path, "r", encoding="utf-8") as f:
                return json.load(f)
        elif file_type == "text":
            with open(file_path, "r", encoding="utf-8") as f:
                return f.read()
        elif file_type in ["excel", "xlsx"]:
            return pd.read_excel(file_path)
        elif file_type == "csv":
            return pd.read_csv(file_path)
        else:
            raise ValueError(f"Unsupported file_type: {file_type}")
    except Exception as e:
        cprint(f"Error reading file {file_path}: {e}", "error")
        raise Exception(f"Error reading file {file_path}: {e}")


def write_file(file_path, data, file_type="text"):
    """
    Writes data to a file at the given path.

    Args:
        file_path (str): The path to the file to write to.
        data (str or dict): The data to write. Can be a string (for text files) or a dictionary (for JSON files).
        file_type (str): The type of the file ('text' or 'json'). Defaults to 'text'.

    Raises:
        ValueError: If the file_type is not supported.
        Exception: For other errors during writing.
    """
    try:
        if file_type == "json":
            content = json.dumps(data, indent=2)
        elif file_type == "text":
            content = data
        else:
            raise ValueError(f"Unsupported file_type: {file_type}")

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
    except Exception as e:
        cprint(f"Error writing file {file_path}: {e}", "error")
        raise Exception(f"Error writing file {file_path}: {e}")


def ensure_directory_exists(dir_path):
    """
    Ensures that the directory at the given path exists.

    Args:
        dir_path (str): The path to the directory to check.

    Creates the directory if it does not exist.
    """
    os.makedirs(dir_path, exist_ok=True)


def copy_files_from_directory(source_dir, destination_dir, clear_destination=False):
    """
    Copies all files from one directory to another.

    Args:
        source_dir (str): The path to the source directory.
        destination_dir (str): The path to the destination directory.
        clear_destination (bool): If True, clears the destination directory before copying (full refresh).
            If False, copies files into the existing destination (append). Defaults to False.

    Exits the program if there is an error copying the files.
    """
    try:
        if clear_destination:
            shutil.rmtree(destination_dir, ignore_errors=True)
            os.makedirs(destination_dir)
        for file_name in os.listdir(source_dir):
            source_file = os.path.join(source_dir, file_name)
            dest_file = os.path.join(destination_dir, file_name)
            if os.path.isfile(source_file):
                shutil.copy2(source_file, dest_file)
    except Exception as e:
        cprint(
            f"Error copying files from {source_dir} to {destination_dir}: {e}", "error"
        )
        exit(1)


def move_file(source_path, target_path, create_dirs=True):
    """
    Move a file from source to target path with optional directory creation.

    Args:
        source_path (str): The path to the source file.
        target_path (str): The path to the target file.
        create_dirs (bool): Whether to create target directories if they don't exist. Defaults to True.

    Returns:
        bool: True if the file was moved successfully, False if source file doesn't exist.

    Raises:
        Exception: For other errors during moving.
    """
    try:
        if not os.path.exists(source_path):
            cprint(f"Warning: Source file not found at {source_path}", "warning")
            return False

        if create_dirs:
            target_dir = os.path.dirname(target_path)
            if target_dir:
                ensure_directory_exists(target_dir)

        shutil.move(source_path, target_path)
        cprint(f"Moved file: {os.path.basename(target_path)}", "success")
        return True

    except Exception as e:
        cprint(f"Error moving file from {source_path} to {target_path}: {e}", "error")
        raise


def remove_directory(dir_path):
    """
    Removes a directory and all its contents.

    Args:
        dir_path (str): The path to the directory to remove.

    Exits the program if there is an error removing the directory.
    """
    try:
        if os.path.exists(dir_path):
            shutil.rmtree(dir_path, onexc=lambda f, p, e: (os.chmod(p, stat.S_IWRITE), f(p)))
        else:
            cprint(f"Error: Directory not found: {dir_path}", "error")
    except Exception as e:
        cprint(f"Error removing directory {dir_path}: {e}", "error")
        exit(1)


def upload_to_s3(file_path: Path, bucket: str, key: str) -> None:
    """Upload a file to S3 bucket."""
    try:
        s3_client = boto3.client("s3")
        s3_client.upload_file(
            str(file_path),
            bucket,
            key,
            ExtraArgs={
                "ContentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            },
        )
        cprint(f"Successfully uploaded to s3://{bucket}/{key}", "success")
    except Exception as e:
        cprint(f"Error uploading to S3: {e}", "error")
