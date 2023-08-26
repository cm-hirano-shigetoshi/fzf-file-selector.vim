import os
import subprocess
import sys
from subprocess import PIPE

import create_fzf_command
import internal_server

FZF = os.environ.get("FZF_FILE_SELECTOR_FZF", "fzf")


def get_origin_path_query(b, c):
    left = get_left(b, c)
    path = b[len(left) : c]
    if (pos := path.rfind("/")) == -1:
        origin_path = "."
        query = path
    else:
        origin_path = path[:pos]
        query = path[pos + 1 :]
    return origin_path, query


def get_selected_items(fd_command, fzf_dict, fzf_port):
    command = f'{fd_command} | {FZF} --listen {fzf_port} {fzf_dict["options"]}'
    proc = subprocess.run(command, shell=True, stdout=PIPE, text=True)
    return proc.stdout


def get_left(b, c):
    if c == 0:
        return ""
    if b[c - 1] == " ":
        return b[:c]
    else:
        pos = b[:c].rfind(" ")
        if pos == -1:
            return ""
        else:
            return b[: pos + 1]


def get_right(b, c):
    return b[c:]


def get_concat_items(items):
    return " ".join(items.rstrip("\n").split("\n"))


def get_buffer_from_items(b, c, items):
    concat_items = get_concat_items(items)
    left = get_left(b, c)
    right = get_right(b, c)
    if left == "":
        return f"{concat_items} {right}"
    else:
        if left[-1] == " ":
            return f"{left}{concat_items} {right}"
        else:
            return f"{left} {concat_items} {right}"


def get_cursor_from_items(b, c, items):
    if (left := get_left(b, c)) == "":
        return len(get_concat_items(items)) + 1
    elif left[-1] == " ":
        return len(left) + len(get_concat_items(items)) + 1
    else:
        return len(left) + 1 + len(get_concat_items(items)) + 1


def main(args):
    org_buffer, org_cursor = args[1], int(args[2])
    origin_path, query = get_origin_path_query(org_buffer, org_cursor)
    port = internal_server.run(origin_path)
    fd_command, fzf_dict, fzf_port = create_fzf_command.run(origin_path, query, port)
    internal_server.set_fzf_port(fzf_port)
    items = get_selected_items(fd_command, fzf_dict, fzf_port)
    if len(items) > 0:
        buffer = get_buffer_from_items(org_buffer, org_cursor, items)
        cursor = get_cursor_from_items(org_buffer, org_cursor, items)
        print(f"{cursor} {buffer}")


if __name__ == "__main__":
    main(sys.argv)
