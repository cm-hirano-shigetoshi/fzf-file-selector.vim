import socket
import sys


def run(start_port=49152):
    for port in range(start_port, 65536):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("localhost", port)) != 0:
                return port
    raise RuntimeError("No open ports found")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        start_port = sys.argv[1]
        port = run(start_port=start_port)
    else:
        port = run()
    print(port, end="")
