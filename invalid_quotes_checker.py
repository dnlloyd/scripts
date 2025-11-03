#!/usr/bin/env python3
# file: syntax_check.py
import ast
import sys
from pathlib import Path

def check(path: str) -> bool:
    try:
        src = Path(path).read_text(encoding="utf-8")
        ast.parse(src, filename=path)
        return False
    except SyntaxError as e:
        line = e.text.rstrip("\n") if e.text else ""
        caret = (" " * (e.offset - 1) + "^") if e.offset and line else ""
        print(f"{path}:{e.lineno}:{e.offset}: SyntaxError: {e.msg}")
        if line:
            print(line)
            if caret:
                print(caret)
        return True

if __name__ == "__main__":
    bad = any(check(p) for p in sys.argv[1:])
    sys.exit(1 if bad else 0)
