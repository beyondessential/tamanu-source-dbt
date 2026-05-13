import sys

from utils import cprint, generate_translation_macro


def main():
    try:
        cprint("Generating translation macro...", "info")
        generate_translation_macro()
    except Exception as e:
        cprint(f"Error generating translation macro: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()
