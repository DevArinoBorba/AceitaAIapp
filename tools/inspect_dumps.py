#!/usr/bin/env python3
"""Inspeciona o dumps.jsonl puxado do celular.

O arquivo fica em /sdcard/Android/data/br.com.aceitaai.app/files/dumps.jsonl
(uma captura de tela por linha). Serve para escrever o parser: mostra os ids e
textos reais das telas do app do motorista.

Uso:
    python tools/inspect_dumps.py dumps.jsonl
    python tools/inspect_dumps.py dumps.jsonl --pkg com.ubercab.driver
    python tools/inspect_dumps.py dumps.jsonl --changed        # só o que mudou
    python tools/inspect_dumps.py dumps.jsonl --grep "R\\$|km|min"
    python tools/inspect_dumps.py dumps.jsonl --ids            # só ids, sem texto
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load(path: Path) -> list[dict]:
    dumps = []
    with path.open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                dumps.append(json.loads(line))
            except json.JSONDecodeError as error:
                print(f"linha {number} inválida: {error}", file=sys.stderr)
    return dumps


def short_id(raw: str) -> str:
    if not raw:
        return "-"
    return raw.split("/")[-1]


def nodes_of(dump: dict) -> list[tuple[str, str]]:
    return [(short_id(n.get("id", "")), n.get("text", "")) for n in dump.get("nodes", [])]


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspeciona dumps.jsonl do Aceita AI")
    parser.add_argument("path", type=Path)
    parser.add_argument("--pkg", help="filtra por pacote")
    parser.add_argument("--changed", action="store_true", help="mostra só nós novos vs. captura anterior")
    parser.add_argument("--grep", help="regex aplicada ao texto do nó")
    parser.add_argument("--ids", action="store_true", help="mostra só o id do nó")
    parser.add_argument("--tail", type=int, default=0, help="mostra só as N últimas capturas")
    args = parser.parse_args()

    dumps = load(args.path)
    if args.pkg:
        dumps = [d for d in dumps if d.get("package") == args.pkg]
    if args.tail:
        dumps = dumps[-args.tail :]

    if not dumps:
        print("nenhuma captura encontrada")
        return 1

    import re

    pattern = re.compile(args.grep) if args.grep else None
    previous: list[tuple[str, str]] = []

    for index, dump in enumerate(dumps, start=1):
        nodes = nodes_of(dump)
        shown = nodes
        marker = ""

        if args.changed:
            before = set(previous)
            shown = [n for n in nodes if n not in before]
            previous = nodes
            marker = f" (+{len(shown)}/{len(nodes)})"
            if not shown:
                continue

        if pattern:
            shown = [n for n in shown if pattern.search(n[1]) or pattern.search(n[0])]
            if not shown:
                continue

        print(f"=== #{index} {dump.get('package')} ({dump.get('appLabel')}) "
              f"nós={len(nodes)}{marker} ===")
        for node_id, text in shown:
            if args.ids:
                print(f"   {node_id}")
            else:
                text = text.replace("\n", " / ")
                print(f"   [{node_id}] {text}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
