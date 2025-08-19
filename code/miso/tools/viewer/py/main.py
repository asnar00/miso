#!/usr/bin/env python3
import argparse


def execute() -> int:
    print('elegant viewer for spec trees')
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description='viewer')
    _ = parser.parse_args()
    raise SystemExit(execute())


if __name__ == "__main__":
    main()
