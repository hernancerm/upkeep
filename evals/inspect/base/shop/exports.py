import os


def write_export(export_dir: str, name: str, body: str) -> None:
    os.makedirs(export_dir, exist_ok=True)
    with open(os.path.join(export_dir, name), "w", encoding="utf-8") as f:
        f.write(body)
