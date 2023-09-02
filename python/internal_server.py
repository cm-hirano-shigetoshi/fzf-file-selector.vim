import atexit
import os
import sys
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

import requests

import create_fzf_command

FD = os.environ.get("FZF_FILE_SELECTOR_FD", "fd")

fzf_port_ = -1

search_origins = []
path_notation_ = "relative"
entity_type_ = "f"
file_filter_ = "default"


def set_fzf_port(fzf_port):
    global fzf_port_
    fzf_port_ = fzf_port
    return True


def get_fd_command(d, path_notation=None, entity_type=None, file_filter=None):
    path_notation = path_notation if path_notation else path_notation_
    entity_type = entity_type if entity_type else entity_type_
    file_filter = file_filter if file_filter else file_filter_

    commands = []
    commands.append(FD)
    commands.append(get_path_notation_option(path_notation))
    commands.append(get_entity_type_option(entity_type))
    commands.append(get_file_filter_option(file_filter))
    commands.append("--color always")
    commands.append("^")
    commands.append(d)

    return " ".join([x for x in commands if len(x) > 0])


def get_entity_type_option(entity_type):
    assert entity_type in ("A", "f", "d")
    if entity_type == "A":
        return ""
    else:
        return f"--type {entity_type}"


def get_file_filter_option(file_filter):
    assert file_filter in ("default", "no-ignore", "hidden", "unrestricted")
    if file_filter == "default":
        return ""
    else:
        return f"--{file_filter}"


def get_parent_dir(d):
    if d.startswith("/"):
        # absolute path
        return os.path.abspath(os.path.dirname(d))
    else:
        # relative path
        return os.path.relpath(f"{d}/..")


def get_path_notation_option(path_notation):
    assert path_notation in ("relative", "absolute"), path_notation
    if path_notation == "relative":
        return ""
    elif path_notation == "absolute":
        return "--absolute-path"


def get_fzf_api_url():
    return f"http://localhost:{fzf_port_}"


def post_to_localhost(*args, **kwargs):
    requests.post(*args, **kwargs, proxies={"http": None})


def update_path_notation(path_notation):
    global path_notation_
    path_notation_ = path_notation


def update_entity_type(entity_type):
    global entity_type_
    entity_type_ = entity_type


def update_file_filter(file_filter):
    global file_filter_
    file_filter_ = file_filter


def update_search_origins(move):
    if move == "up":
        if os.path.abspath(search_origins[-1]) != "/":
            search_origins.append(get_parent_dir(search_origins[-1]))
            return True
    elif move == "back":
        if len(search_origins) > 1:
            search_origins.pop(-1)
            return True
    return False


def get_origin_move_command(d):
    return f"reload({get_fd_command(d)})+change-header({create_fzf_command.get_absdir_view(d)})"


def get_entity_type_command(entity_type):
    return f"reload({get_fd_command(search_origins[-1], entity_type=entity_type)})"


def get_file_filter_command(file_filter):
    return f"reload({get_fd_command(search_origins[-1], file_filter=file_filter)})"


def get_path_notation_command(path_notation):
    return f"reload({get_fd_command(search_origins[-1], path_notation=path_notation)})"


def request_to_fzf(params):
    try:
        if "origin_move" in params:
            move = params["origin_move"][0]
            succeeded = update_search_origins(move)
            if succeeded:
                command = get_origin_move_command(search_origins[-1])
                post_to_localhost(get_fzf_api_url(), data=command)
                return True
        elif "path_notation" in params:
            path_notation = params["path_notation"][0]
            update_path_notation(path_notation)
            command = get_path_notation_command(path_notation)
            post_to_localhost(get_fzf_api_url(), data=command)
        elif "entity_type" in params:
            entity_type = params["entity_type"][0]
            update_entity_type(entity_type)
            command = get_entity_type_command(entity_type)
            post_to_localhost(get_fzf_api_url(), data=command)
        elif "file_filter" in params:
            file_filter = params["file_filter"][0]
            update_file_filter(file_filter)
            command = get_file_filter_command(file_filter)
            post_to_localhost(get_fzf_api_url(), data=command)
        return True
    except Exception as e:
        print(e, file=sys.stderr)
        return False


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed_path.query)
        if "set_fzf_port" in params:
            succeeded = set_fzf_port(int(params["set_fzf_port"][0]))
        else:
            succeeded = request_to_fzf(params)
        if succeeded:
            self.send_response(200)
            self.end_headers()

    def log_message(self, format, *args):
        # supress any log messages
        return


class ThreadedHTTPServer(threading.Thread):
    def bind_socket(self):
        self.httpd = HTTPServer(("", 0), RequestHandler)
        return self.httpd.server_port

    def run(self):
        self.httpd.serve_forever()

    def stop(self):
        self.httpd.shutdown()


def start_server():
    server = ThreadedHTTPServer(daemon=True)
    port = server.bind_socket()
    atexit.register(server.stop)
    server.start()
    return port


def run_as_thread(origin_path):
    port = start_server()

    search_origins.append(origin_path)
    update_path_notation("relative")
    update_entity_type("f")
    update_file_filter("default")

    return port


def run(origin_path, server_port):
    search_origins.append(origin_path)
    update_path_notation("relative")
    update_entity_type("f")
    update_file_filter("default")

    HTTPServer(("", int(server_port)), RequestHandler).serve_forever()


if __name__ == "__main__":
    args = sys.argv[1:]
    run(*args)
