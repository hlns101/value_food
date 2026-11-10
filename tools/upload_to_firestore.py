#!/usr/bin/env python3
"""
Upload products_clean.json to Firestore (collection: products).

Setup:
    pip install firebase-admin
    Firebase console -> Project settings -> Service accounts ->
    "Generate new private key" -> save as serviceAccountKey.json
    (NEVER commit it or leave it in OneDrive; delete it when done.)

Usage:
    gcloud auth application-default login      (once; no key file needed)
    python upload_to_firestore.py products_import.json --replace

--replace       deletes ALL existing docs in `products` first (avoids duplicates)
--skip-review   uploads only products with needsReview == false
Document ID = barcode, or the product's generated "id" when the barcode is missing, so re-running overwrites instead of duplicating.
"""
import argparse
import json

import firebase_admin
from firebase_admin import credentials, firestore


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("json_file")
    ap.add_argument("--replace", action="store_true")
    ap.add_argument("--skip-review", action="store_true")
    a = ap.parse_args()

    firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": "valuefood-01"}
    )
    db = firestore.client()
    col = db.collection("products")

    if a.replace:
        n = 0
        while True:
            docs = list(col.limit(400).stream())
            if not docs:
                break
            batch = db.batch()
            for d in docs:
                batch.delete(d.reference)
            batch.commit()
            n += len(docs)
        print(f"Deleted {n} old documents")

    with open(a.json_file, encoding="utf-8") as f:
        items = json.load(f)
    if a.skip_review:
        items = [p for p in items if not p.get("needsReview")]

    batch, count = db.batch(), 0
    for p in items:
        batch.set(col.document(p.get("barcode") or p["id"]), p)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"Uploaded {count} products")


if __name__ == "__main__":
    main()