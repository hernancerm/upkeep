from pathlib import Path


def write_export(export_dir: str, name: str, body: str) -> None:
    out_dir = Path(export_dir)
    out_dir.mkdir(parents=True)
    (out_dir / name).write_text(body, encoding="utf-8")
