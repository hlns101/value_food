#!/usr/bin/env python3
"""
Safe import for ValueFood `products` collection (v2: matches existing schema).

 - NEVER deletes anything.
 - New products: created only if the doc ID does not already exist.
 - Existing updates: merged into existing docs, only adding off* fields.
 - DRY RUN by default. Nothing is written unless you pass --commit.
 - Before any write, existing docs are backed up to products_backup_<time>.json

    python3 import_to_firestore.py                      # dry run
    python3 import_to_firestore.py --commit --limit 5   # test with 5 new docs
    python3 import_to_firestore.py --commit             # full import
"""
import argparse
import json
from datetime import datetime

import firebase_admin
from firebase_admin import credentials, firestore

PROJECT_ID = "valuefood-01"
COLLECTION = "products"
NEW_FILE = "valuefood_firestore_new_products_import.json"
UPD_FILE = "valuefood_firestore_existing_product_updates.json"

# my field name -> your existing Firestore field name
RENAME = {
    "price_php": "price",
    "calories_kcal": "calories",
    "fat_g": "fat",
    "saturated_fat_g": "saturatedFat",
    "carbs_g": "carbs",
    "sugars_g": "sugars",
    "protein_g": "protein",
    "sodium_mg": "sodium",
    "ingredients_text": "ingredients",
    "categories": "category",
    "source": "dataSource",
    "quality_flags": "issues",
}


def camel(key):
    parts = key.split("_")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def convert_new(doc_id, d):
    out = {}
    for k, v in d.items():
        out[RENAME.get(k) or camel(k)] = v
    out["id"] = doc_id
    out["priceReviewStatus"] = "missing_price"
    flags = d.get("quality_flags") or []
    out["isPhilippine"] = False if "country_not_philippines" in flags else None
    return out


def convert_merge(d):
    return {camel(k): v for k, v in d.items()}


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--commit", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--skip-review", action="store_true")
    ap.add_argument("--skip-updates", action="store_true")
    a = ap.parse_args()

    firebase_admin.initialize_app(credentials.ApplicationDefault(), {"projectId": PROJECT_ID})
    db = firestore.client()
    col = db.collection(COLLECTION)

    new_items = json.load(open(NEW_FILE, encoding="utf-8"))
    updates = json.load(open(UPD_FILE, encoding="utf-8"))

    if a.skip_review:
        new_items = [x for x in new_items if not x["data"].get("needs_review")]
    if a.limit:
        new_items = new_items[: a.limit]

    existing = {d.id: d.to_dict() for d in col.stream()}
    print(f"Existing docs in '{COLLECTION}': {len(existing)}")

    to_create = [x for x in new_items if x["doc_id"] not in existing]
    to_merge = [] if a.skip_updates else [u for u in updates if u["doc_id"] in existing]
    print(f"New products to create : {len(to_create)}")
    print(f"Existing docs to merge : {len(to_merge)}")

    if to_create:
        sample = convert_new(to_create[0]["doc_id"], to_create[0]["data"])
        sample.pop("ingredients", None)
        print("\nSample new doc (fields):")
        print(json.dumps(sample, indent=1, ensure_ascii=False))

    if not a.commit:
        print("\nDRY RUN - nothing written.")
        return

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    bpath = f"products_backup_{stamp}.json"
    json.dump(existing, open(bpath, "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
    print(f"\nBackup saved: {bpath}")

    created = 0
    for grp in chunks(to_create, 400):
        batch = db.batch()
        for x in grp:
            batch.set(col.document(x["doc_id"]), convert_new(x["doc_id"], x["data"]))
        batch.commit()
        created += len(grp)
    print(f"Created {created} new products")

    merged = 0
    for grp in chunks(to_merge, 400):
        batch = db.batch()
        for u in grp:
            batch.set(col.document(u["doc_id"]), convert_merge(u["merge"]), merge=True)
        batch.commit()
        merged += len(grp)
    print(f"Merged {merged} existing products")


if __name__ == "__main__":
    main()