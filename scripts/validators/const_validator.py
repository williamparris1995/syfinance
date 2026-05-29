"""Const/i18n validator — ensures JSX string literals use i18n or are const-defined."""

import re
from pathlib import Path
from .base import BaseValidator

# JSX attributes that accept non-i18n string values
JSX_STRING_ATTRS = {
    "className", "style", "type", "id", "name", "to", "key",
    "variant", "size", "side", "as", "role", "dir", "lang",
    "slot", "action", "method", "target", "rel", "href",
    "src", "alt", "placeholder",
    # SVG / chart attributes
    "d", "fill", "stroke", "viewBox", "xmlns",
    "cx", "cy", "r", "x", "y", "width", "height",
    "points", "offset", "data", "format", "ticks", "domain",
}

# Pattern matching string literals: "..." or '...'
STRING_LITERAL_RE = re.compile(r"""(?<!\\)(["'])(?:(?!\1).){1,}\1""")


class ConstValidator(BaseValidator):
    """Validates that string literals in TSX files use i18n or are const-defined."""

    def __init__(self, project_root: Path):
        super().__init__(project_root)

    def validate(self) -> bool:
        ts_src = self.project_root / "src"
        if not ts_src.exists():
            return True

        for file_path in ts_src.rglob("*.tsx"):
            if self.should_skip_file(file_path):
                continue
            try:
                lines = file_path.read_text(encoding="utf-8").split("\n")
            except Exception:
                continue

            for i, line in enumerate(lines, 1):
                self._check_line(file_path, i, line)

        return len(self.errors) == 0

    def _check_line(self, file_path: Path, line_num: int, line: str):
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("//") or stripped.startswith("*"):
            return

        # Skip import statements
        if stripped.startswith("import "):
            return

        # Skip type/interface declarations
        if re.match(r"^\s*(export\s+)?(type|interface)\s+", line):
            return

        # Skip lines using t() i18n calls
        if re.search(r'\bt\s*\(', line):
            return

        # Skip const/let/var declarations (non-display constants are OK)
        if re.match(r"^\s*(const|let|var)\s+", line):
            return

        # Skip lines with function signatures
        if re.match(r"^\s*(async\s+)?function\s+", line):
            return
        if re.match(r"^\s*(export\s+)?(default\s+)?function", line):
            return

        # Only check lines that look like JSX (contain < and >)
        if "<" not in line:
            return

        # Find string literals in the line
        for match in STRING_LITERAL_RE.finditer(line):
            literal = match.group(0)
            value = literal[1:-1]

            # Skip empty or very short strings
            if len(value) <= 1:
                continue

            # Skip hex color codes (e.g. #6B7280, #EF4444, #10B981)
            if re.match(r"^#[0-9A-Fa-f]{3,8}$", value):
                continue

            # Skip percentage/numeric values (e.g. 100%, 3.5, 42)
            if re.match(r"^\d+\.?\d*%?$", value):
                continue

            # Skip Tailwind/CSS class strings (contain CSS-like tokens)
            if re.search(
                r"(text|bg|border|p-|m-|w-|h-|flex|grid|rounded|shadow|font|gap|space|opacity|hover:|dark:|focus:)",
                value,
            ):
                continue

            # Skip SVG data strings (short strings of numbers, dots, spaces, commas)
            if re.match(r"^[\d.\s,]+$", value):
                continue

            # Skip code fragments from inline handlers (contain ); or function-call patterns)
            if re.search(r"\)\s*;\s*\w+", value):
                continue

            # Skip developer-facing error messages (throw new Error / console.error etc.)
            if re.search(r"\b(throw\s+new\s+Error|console\.(error|warn))\s*\(", line):
                continue

            # Skip strings that look like codes/keys (all caps, dots, slashes, hyphens)
            if re.match(r"^[A-Z_a-z0-9./:_-]+$", value):
                continue

            # Check if this string is inside a known JSX attribute
            prefix = line[: match.start()]

            # If className appears anywhere in the prefix, skip (multi-expression classes)
            if "className" in prefix:
                continue

            attr_match = re.search(r"(\w+)\s*=\s*$", prefix)
            if attr_match:
                attr_name = attr_match.group(1)
                if attr_name in JSX_STRING_ATTRS:
                    continue

            # This is a bare string literal in JSX that should use t()
            self.add_error(
                str(file_path),
                line_num,
                f"Bare string literal {literal} in JSX must use t() for i18n",
            )
