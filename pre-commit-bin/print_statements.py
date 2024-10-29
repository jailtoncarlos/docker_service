from __future__ import annotations

import argparse
import ast
import tokenize
import traceback
from typing import List, Optional, Sequence

FILENAMES = ("views.py", "forms.py", "tasks.py", "models.py")


def check_file(filename: str) -> int:
    try:
        with open(filename, "rb") as f:
            ast.parse(f.read(), filename=filename)
    except SyntaxError:
        print(f"{filename} - Could not parse ast")
        print()
        print("	" + traceback.format_exc().replace("", ""))
        print()
        return 1

    lines: List[Optional[tokenize.TokenInfo]] = []
    with tokenize.open(filename) as f:
        tokens = tokenize.generate_tokens(f.readline)
        line = None
        for token in tokens:
            if line:
                if (
                    token.start[0] == line.start[0]
                    and token.type == 61
                    and token.string == "# NOQA"
                ):
                    line = None
                    continue
                if token.start[0] > line.start[0]:
                    lines.append(line)
                    line = None
                    continue
            if token.string == "print" and token.type == 1:
                line = token
                continue

    for line in lines:
        if line is not None:
            print(f"{filename}:{line.start[0]}:{line.start[1]}: {line.string} found")

    return int(bool(lines))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("filenames", nargs="*", help="Filenames to run")
    args = parser.parse_args(argv)

    retv = 0
    for filename in args.filenames:
        for pattern in FILENAMES:
            if filename.endswith(pattern):
                retv |= check_file(filename)
    return retv


if __name__ == "__main__":
    raise SystemExit(main())
