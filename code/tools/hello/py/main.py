#!/usr/bin/env python3
import argparse


def execute() -> int:
    print('ohai miso ᕦ(ツ)ᕤ')
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description='hello')
    _ = parser.parse_args()
    raise SystemExit(execute())


if __name__ == "__main__":
    main()
