#!/usr/bin/env python3
"""
ValueFood catalog builder
-------------------------
Rebuilds your products.json so EVERY product has nutrition per 100 g in the
units the app expects (kcal, mg sodium, g sugars, g saturated fat), using
Open Food Facts (OFF) as the main source and your existing data as fallback.

Usage (needs internet + `pip install requests`):
    python build_catalog.py products.json --email you@example.com
    python build_catalog.py products.json --email you@example.com --prices prices.csv

    # dry run without internet (uses only the data already in products.json):
    python build_catalog.py products.json --offline

Outputs:
    products_clean.json    -> catalog for Firestore (see upload_to_firestore.py)
    catalog_report.txt     -> which products need manual checking and why
    prices_template.csv    -> fill in `price_php`, then re-run with --prices

Open Food Facts data is licensed ODbL: credit "Open Food Facts contributors"
in your thesis (the output keeps a sourceUrl per product).
"""
import argparse
import csv
import json
import re
import sys
import time

OFF_URL = "https://world.openfoodfacts.org/api/v2/product/{}.json"
OFF_FIELDS = ("code,product_name,brands,quantity,serving_size,nutriments,"
              "ingredients_text,allergens_tags,categories,nutrition_data_per")
CORE = ["calories", "sodium", "sugars", "saturatedFat"]

# Order matters: first rule that matches wins. Keep categories COARSE so each
# one has enough products for the KNN to compare (aim for 10+ per category).
CATEGORY_RULES = [
    ("Canned Fruit", ["fruit cocktail", "fruit salad", "canned fruit"]),
    ("Canned Protein", ["sardine", "tuna", "corned beef", "luncheon", "meat loaf",
                        "canned meat", "canned fish", "canned foods"]),
    ("Noodles", ["instant noodle", "noodle", "pasta"]),
    ("Snacks", ["chips", "crisps", "snack", "cracker", "biscuit", "piattos", "skyflakes"]),
    ("Condiments", ["mayonnaise", "sauce", "condiment", "ketchup"]),
    ("Beverages", ["beverages and beverages preparations", "flavoured drinks",
                   "drink", "juice", "milo", "coffee"]),
]


# ----------------------------------------------------------------- helpers
def num(x):
    try:
        return None if x is None or x == "" else float(x)
    except (TypeError, ValueError):
        return None


def barcode_variants(code):
    c = re.sub(r"\D", "", str(code))
    out = []
    for v in (c, c.lstrip("0"), c.zfill(13), c.zfill(12)):
        if v and v not in out:
            out.append(v)
    return out


def guess_category(*texts):
    blob = " ".join(t for t in texts if t).lower()
    for cat, words in CATEGORY_RULES:
        if any(w in blob for w in words):
            return cat
    return "Other"


def clean_ingredients(text):
    if not text:
        return []
    t = re.sub(r"\(.*?\)", " ", str(text))                 # drop (...) details
    t = re.sub(r"\b(noodles|seasonings?|ingredients|contains)\s*:", ",", t, flags=re.I)
    t = re.sub(r"\d+(\.\d+)?\s*%", " ", t)                 # drop percentages
    parts = re.split(r"[,;.]", t)
    tags = [re.sub(r"\s+", " ", p).strip().lower() for p in parts]
    return [p for p in tags if 1 < len(p) <= 40][:30]


def off_per100(n):
    """OFF nutriments -> our units. OFF stores sodium/salt in grams per 100 g."""
    kcal = num(n.get("energy-kcal_100g"))
    if kcal is None:
        kj = num(n.get("energy-kj_100g")) or num(n.get("energy_100g"))
        kcal = kj / 4.184 if kj else None
    sodium_g, salt_g = num(n.get("sodium_100g")), num(n.get("salt_100g"))
    if sodium_g is not None:
        sodium = sodium_g * 1000
    elif salt_g is not None:
        sodium = salt_g * 400          # salt is ~40% sodium
    else:
        sodium = None
    return {
        "calories": kcal, "sodium": sodium,
        "sugars": num(n.get("sugars_100g")),
        "saturatedFat": num(n.get("saturated-fat_100g")),
        "fat": num(n.get("fat_100g")), "carbs": num(n.get("carbohydrates_100g")),
        "protein": num(n.get("proteins_100g")),
    }


def local_per100(local):
    """Existing nutri_facts -> our units. Returns (values, basis_is_per_100g)."""
    f = local.get("nutri_facts") or {}
    sodium_g, salt_g = num(f.get("sodium_g")), num(f.get("salt_g"))
    sodium = sodium_g * 1000 if sodium_g is not None else (
        salt_g * 400 if salt_g is not None else None)
    vals = {
        "calories": num(f.get("energy_kcal")), "sodium": sodium,
        "sugars": num(f.get("sugars_g")), "saturatedFat": num(f.get("saturated_fat_g")),
        "fat": num(f.get("fat_g")), "carbs": num(f.get("carbohydrates_g")),
        "protein": num(f.get("protein_g")),
    }
    basis = str(local.get("nutrition_basis") or "").lower()
    return vals, ("100" in basis)


def sanity_issues(v):
    issues = []
    cal, sod, sug, sat = (v.get(k) for k in CORE)
    if cal is not None and not 0 <= cal <= 900:
        issues.append(f"calories {cal:.0f} outside 0-900 per 100 g")
    if sod is not None and not 0 <= sod <= 8000:
        issues.append(f"sodium {sod:.0f} mg outside 0-8000 per 100 g")
    if sug is not None and not 0 <= sug <= 100:
        issues.append(f"sugars {sug} outside 0-100 g")
    if sat is not None and v.get("fat") is not None and sat > v["fat"] + 0.5:
        issues.append("saturated fat is higher than total fat")
    if sug is not None and v.get("carbs") is not None and sug > v["carbs"] + 0.5:
        issues.append("sugars are higher than total carbohydrates")
    f, c, p = v.get("fat"), v.get("carbs"), v.get("protein")
    if cal and None not in (f, c, p):
        expected = 9 * f + 4 * c + 4 * p
        if expected > 0 and abs(cal - expected) / expected > 0.30:
            issues.append(f"calories ({cal:.0f}) don't match macros (~{expected:.0f})")
    return issues


# ------------------------------------------------------------------ core
def build_record(local, off, price):
    n = (off or {}).get("nutriments") or {}
    off_vals = off_per100(n) if off else {}
    loc_vals, loc_is_100g = local_per100(local)

    vals, used = {}, set()
    for k in CORE + ["fat", "carbs", "protein"]:
        if off_vals.get(k) is not None:
            vals[k] = off_vals[k]; used.add("off")
        elif loc_vals.get(k) is not None:
            vals[k] = loc_vals[k]; used.add("local")
        else:
            vals[k] = None

    issues = []
    missing = [k for k in CORE if vals[k] is None]
    if missing:
        issues.append("missing: " + ", ".join(missing))
    if off is None:
        issues.append("not found on Open Food Facts")
    if "local" in used and not loc_is_100g:
        issues.append("some values come from products.json with UNKNOWN basis "
                      "(per serving or per 100 g?) - verify on the physical label")
    issues += sanity_issues(vals)

    if used == {"off"}:
        source, basis = "openfoodfacts", "per 100 g"
    elif used == {"local"} and loc_is_100g:
        source, basis = "manual (per 100 g)", "per 100 g"
    elif used == {"off", "local"}:
        source, basis = "openfoodfacts+local", "per 100 g" if loc_is_100g else "mixed/unknown"
    else:
        source, basis = "local (unknown basis)", "unknown"

    off_ing = clean_ingredients((off or {}).get("ingredients_text"))
    ingredients = off_ing or clean_ingredients(local.get("description"))
    allergens = {a.lower().strip() for a in (local.get("allergens") or [])}
    for tag in (off or {}).get("allergens_tags") or []:
        allergens.add(tag.split(":")[-1].replace("-", " ").lower())

    name = local.get("product_name") or (off or {}).get("product_name") or ""
    barcode = re.sub(r"\D", "", str(local.get("barcode", "")))
    rec = {
        "barcode": barcode,
        "name": name,
        "category": guess_category(local.get("category"), (off or {}).get("categories"), name),
        "price": float(price) if price else 0.0,
        "calories": round(vals["calories"] or 0, 1),
        "sodium": round(vals["sodium"] or 0, 1),         # mg per 100 g
        "sugars": round(vals["sugars"] or 0, 1),         # g per 100 g
        "saturatedFat": round(vals["saturatedFat"] or 0, 1),
        "fat": vals["fat"], "carbs": vals["carbs"], "protein": vals["protein"],
        "allergens": sorted(allergens),
        "ingredients": ingredients,
        "nutritionBasis": basis,
        "dataSource": source,
        "packSize": (off or {}).get("quantity") or "",
        "sourceUrl": (f"https://world.openfoodfacts.org/product/{(off or {}).get('code')}"
                      if off else local.get("source_url") or ""),
        "imageLink": local.get("image_link") or "",
        "needsReview": bool(issues) or not price,
        "issues": issues + ([] if price else ["price not set"]),
    }
    return rec


def fetch_off(session, code, delay=0.8):
    """Try barcode variants; return OFF `product` dict or None."""
    import requests
    for v in barcode_variants(code):
        for attempt in range(3):
            try:
                r = session.get(OFF_URL.format(v), params={"fields": OFF_FIELDS}, timeout=20)
            except requests.RequestException as e:
                print(f"   network error for {v}: {e}")
                time.sleep(2)
                continue
            time.sleep(delay)
            if r.status_code == 429:           # rate limited: wait and retry
                time.sleep(5 * (attempt + 1))
                continue
            if r.status_code != 200:
                break
            j = r.json()
            if j.get("status") == 1 and j.get("product"):
                return j["product"]
            break
    return None


def load_prices(path):
    prices = {}
    if not path:
        return prices
    with open(path, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            p = num(row.get("price_php"))
            if p:
                prices[re.sub(r"\D", "", row["barcode"]).lstrip("0")] = p
    return prices


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--out", default="products_clean.json")
    ap.add_argument("--prices", help="CSV with columns barcode,price_php")
    ap.add_argument("--email", default="saprivatepua@gmail.com",
                    help="goes in the User-Agent so Open Food Facts can contact you")
    ap.add_argument("--offline", action="store_true", help="skip Open Food Facts")
    a = ap.parse_args()

    with open(a.input, encoding="utf-8") as f:
        items = json.load(f)
    prices = load_prices(a.prices)

    session = None
    if not a.offline:
        import requests
        session = requests.Session()
        session.headers["User-Agent"] = f"ValueFood-Thesis/1.0 (student project; {a.email})"

    out, report = [], []
    for i, local in enumerate(items, 1):
        code = local.get("barcode")
        print(f"[{i}/{len(items)}] {local.get('product_name')} ({code})")
        off = fetch_off(session, code) if session else None
        key = re.sub(r"\D", "", str(code)).lstrip("0")
        existing_price = num(local.get("price_php")) or num(local.get("price"))
        rec = build_record(local, off, prices.get(key) or existing_price)
        out.append(rec)
        flag = "REVIEW" if rec["needsReview"] else "ok"
        report.append(f"{flag:7} {rec['name']} [{rec['category']}] src={rec['dataSource']}"
                      + "".join(f"\n          - {x}" for x in rec["issues"]))

    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
    with open("catalog_report.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    with open("prices_template.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["barcode", "name", "price_php"])
        for r in out:
            w.writerow([r["barcode"], r["name"], r["price"] or ""])

    cats = {}
    for r in out:
        cats[r["category"]] = cats.get(r["category"], 0) + 1
    print("\nCategories:", cats)
    print(f"{sum(r['needsReview'] for r in out)}/{len(out)} products need review "
          f"-> see catalog_report.txt")
    print(f"Wrote {a.out}. Fill prices_template.csv and re-run with --prices.")


if __name__ == "__main__":
    sys.exit(main())