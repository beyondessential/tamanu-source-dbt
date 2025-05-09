import json
import os
import shutil
from pathlib import Path

import boto3


def ensure_file_exists(file_path):
    """
    Ensures that the file at the given path exists.

    Args:
        file_path (str): The path to the file to check.

    Exits the program if the file does not exist.
    """
    if not os.path.isfile(file_path):
        print(f"Error: File not found: {file_path}")
        exit(1)


def read_file(file_path, file_type="text"):
    """
    Reads the contents of a file at the given path.

    Args:
        file_path (str): The path to the file to read.
        file_type (str): The type of the file ('text' or 'json'). Defaults to 'text'.

    Returns:
        str or dict: The file content as a string (for text files) or a dictionary (for JSON files).

    Raises:
        FileNotFoundError: If the file does not exist.
        ValueError: If the file_type is not supported.
        Exception: For other errors during reading or parsing.
    """
    try:
        ensure_file_exists(file_path)
        with open(file_path, "r", encoding="utf-8") as f:
            data = f.read()
            if file_type == "json":
                return json.loads(data)
            elif file_type == "text":
                return data
            else:
                raise ValueError(f"Unsupported file_type: {file_type}")
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
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
        print(f"Error writing file {file_path}: {e}")
        raise Exception(f"Error writing file {file_path}: {e}")


def ensure_directory_exists(dir_path):
    """
    Ensures that the directory at the given path exists.

    Args:
        dir_path (str): The path to the directory to check.

    Creates the directory if it does not exist.
    """
    os.makedirs(dir_path, exist_ok=True)


def copy_files_from_directory(source_dir, destination_dir):
    """
    Copies all files from one directory to another.

    Args:
        source_dir (str): The path to the source directory.
        destination_dir (str): The path to the destination directory.

    Exits the program if there is an error copying the files.
    """
    try:
        for file_name in os.listdir(source_dir):
            source_file = os.path.join(source_dir, file_name)
            dest_file = os.path.join(destination_dir, file_name)
            if os.path.isfile(source_file):
                shutil.copy2(source_file, dest_file)
    except Exception as e:
        print(f"Error copying files from {source_dir} to {destination_dir}: {e}")
        exit(1)


def remove_directory(dir_path):
    """
    Removes a directory and all its contents.

    Args:
        dir_path (str): The path to the directory to remove.

    Exits the program if there is an error removing the directory.
    """
    try:
        if os.path.exists(dir_path):
            shutil.rmtree(dir_path)
        else:
            print(f"Error: Directory not found: {dir_path}")
    except Exception as e:
        print(f"Error removing directory {dir_path}: {e}")
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
                "ACL": "public-read",
                "ContentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            },
        )
        print(f"Successfully uploaded to s3://{bucket}/{key}")
    except Exception as e:
        print(f"Error uploading to S3: {e}")
