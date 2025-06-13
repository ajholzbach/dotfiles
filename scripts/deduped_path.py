#!/usr/bin/python3
# run the following command to fix PATH variable
# export PATH=$(./deduped_path.py)
import os


def main():
    # Get the current PATH environment variable
    path = os.environ.get("PATH", "")

    # Split the PATH into a list of directories
    path_list = path.split(":")

    # Remove duplicates while preserving order
    unique_path_list = sorted(set(path_list), key=path_list.index)

    # Join the list back into a single string
    new_path = ":".join(unique_path_list)

    # Print the new PATH
    print(new_path)


if __name__ == "__main__":
    main()
