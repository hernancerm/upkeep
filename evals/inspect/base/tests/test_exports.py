from shop.exports import write_export


def test_write_export(tmp_path):
    export_dir = tmp_path / "exports"
    write_export(str(export_dir), "orders.csv", "id,total\n1,50\n")
    assert (export_dir / "orders.csv").read_text(encoding="utf-8") == "id,total\n1,50\n"
