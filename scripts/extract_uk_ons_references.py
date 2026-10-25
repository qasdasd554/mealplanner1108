"""Offline extraction of ONS national averages; never imports shop stock/prices.

Uses openpyxl only in the author's tools, not in the app/backend runtime.
The source workbook is read-only. JSON is a generated reference asset.
"""
import argparse
from datetime import date
from decimal import Decimal
import hashlib
import json
from pathlib import Path


def extract(path, *, as_of):
    from openpyxl import load_workbook

    book = load_workbook(path, read_only=True, data_only=True)
    latest = {}
    try:
        sheet = book["Average price"]
        # ONS declares the used range as A1; do not truncate to that dimension.
        sheet.reset_dimensions()
        values = sheet.values
        headers = next(values)
        for values_row in values:
            row = dict(zip(headers, values_row))
            if row.get("Category1") != "Groceries":
                continue
            period = date.fromisoformat(row["INDEX_DATE"])
            if period > as_of:
                continue
            key = (str(row["CONSUMPTION_SEGMENT_CODE"]), row["ID_DESC"])
            if key in latest and period == latest[key][0] and row != latest[key][1]:
                raise ValueError("Conflicting ONS rows for the same item/month")
            if key not in latest or period > latest[key][0]:
                latest[key] = (period, row)
    finally:
        book.close()
    records = []
    for (code, name), (period, row) in sorted(latest.items()):
        raw = row.get("AVERAGE_PRICE")
        price = None if raw in (None, "-", "") else Decimal(str(raw))
        if price is not None and (not price.is_finite() or price <= 0 or price != price.quantize(Decimal("0.01"))):
            raise ValueError("Unexpected ONS average price")
        records.append(dict(code=code, name=name, reference_unit=row.get("WEIGHT_SIZE") or None,
            price_gbp=str(price.quantize(Decimal("0.01"))) if price is not None else None,
            period=period.strftime("%Y-%m"), category=row.get("Category2")))
    if not records:
        raise ValueError("No grocery references in the selected ONS workbook")
    return dict(schema_version=1, kind="national_average_reference", currency="GBP",
        source_url="https://www.ons.gov.uk/economy/inflationandpriceindices/articles/shoppingpricescomparisontool/latest",
        download_url="https://github.com/onsdigital/cpi-items-actions/raw/main/datadownload.xlsx",
        publisher="Office for National Statistics", licence="OGL-3.0",
        source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), retrieved_on=as_of.isoformat(),
        retailer_prices=False, confirms_availability=False, units_are_actual_packages=False, records=records)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--as-of", required=True, type=date.fromisoformat)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--check", action="store_true", help="Verify the generated projection without changing any file")
    args = parser.parse_args()
    if args.output.exists() and not args.check:
        raise SystemExit("Output already exists; review it before replacing a reference dataset")
    result = extract(args.source, as_of=args.as_of)
    if args.check:
        if json.loads(args.output.read_text(encoding="utf-8")) != result:
            raise SystemExit("The generated reference projection differs from the original source")
    else:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(dict(records=len(result["records"]), missing=sum(row["price_gbp"] is None for row in result["records"]),
        periods=sorted({row["period"] for row in result["records"]}), source_sha256=result["source_sha256"])))
