#!/usr/bin/env python3
"""
Estimate Philippine retail prices with Gemini and save progress after every product.

Install:
    pip install google-genai

Set your key in Windows CMD:
    set GEMINI_API_KEY=YOUR_NEW_KEY

Run:
    python estimate_prices.py products_clean.json
    python estimate_prices.py products_clean.json --no-search
    python estimate_prices.py products_clean.json --resume

The script never overwrites manually entered prices. It writes the output file
after each product so completed estimates are not lost if the API becomes
unavailable.
"""
import argparse
import datetime
import json
import math
import os
import re
import sys
import time

PROMPT = """You are helping a Philippine grocery budgeting app.
Estimate the typical retail price in Philippine pesos (PHP) of ONE retail pack
of this product at ordinary Philippine supermarkets and groceries.

Product: {name}
Barcode: {barcode}
Pack size: {pack}
Category: {category}

Give a realistic min/typical/max range in PHP. If uncertain, use low confidence.
Do not invent sources. Reply with ONLY this JSON:
{{"min": 0, "typical": 0, "max": 0,
  "confidence": "low|medium|high", "note": "one short sentence"}}"""


def save_json(path, items):
    temp_path = path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2, ensure_ascii=False)
    os.replace(temp_path, path)


def parse_estimate(text):
    if not text:
        return None
    match = re.search(r"\{.*\}", text, re.S)
    if not match:
        return None
    try:
        data = json.loads(match.group(0))
        values = [float(data[k]) for k in ("min", "typical", "max")]
        if not all(math.isfinite(v) for v in values):
            return None
        lo, typical, hi = values
    except (ValueError, KeyError, TypeError):
        return None

    if not (5 <= lo <= typical <= hi <= 3000):
        return None

    confidence = str(data.get("confidence", "low")).lower()
    if confidence not in ("low", "medium", "high"):
        confidence = "low"
    if hi > lo * 4:
        confidence = "low"

    return {
        "min": round(lo, 2),
        "typical": round(typical, 2),
        "max": round(hi, 2),
        "confidence": confidence,
        "note": str(data.get("note", ""))[:200],
    }


def grounding_sources(response):
    try:
        chunks = response.candidates[0].grounding_metadata.grounding_chunks or []
        sources = []
        for chunk in chunks:
            web = getattr(chunk, "web", None)
            if web:
                title = getattr(web, "title", None)
                uri = getattr(web, "uri", None)
                if title or uri:
                    sources.append({"title": title or "", "url": uri or ""})
        return sources[:5]
    except Exception:
        return []


def apply_estimate(record, estimate, sources, used_search):
    record["price"] = estimate["typical"]
    record["priceMin"] = estimate["min"]
    record["priceMax"] = estimate["max"]
    record["priceEstimated"] = True
    record["priceConfidence"] = estimate["confidence"]
    record["priceNote"] = estimate["note"]
    record["priceSources"] = sources
    record["priceSearchGrounded"] = bool(used_search and sources)
    record["priceCurrency"] = "PHP"
    record["priceEstimatedAt"] = datetime.date.today().isoformat()
    record["issues"] = [
        issue for issue in record.get("issues", [])
        if issue not in ("price not set", "price estimation failed")
    ]
    record["needsReview"] = bool(record["issues"]) or (
        estimate["confidence"] == "low" or (used_search and not sources)
    )
    return record


def error_kind(error):
    message = str(error).upper()
    code = getattr(error, "code", None) or getattr(error, "status_code", None)
    if code == 429 or "429" in message or "RESOURCE_EXHAUSTED" in message:
        # A quota-exhausted response will not be fixed by retrying immediately.
        if "QUOTA" in message or "RESOURCE_EXHAUSTED" in message:
            return "quota"
        return "rate_limit"
    if code == 503 or "503" in message or "UNAVAILABLE" in message:
        return "temporary"
    return "other"


def ask_gemini(client, types, model, prompt, use_search, max_retries=3):
    config = types.GenerateContentConfig(
        temperature=0,
        max_output_tokens=1024,
        tools=[types.Tool(google_search=types.GoogleSearch())] if use_search else None,
    )

    for attempt in range(max_retries):
        try:
            response = client.models.generate_content(
                model=model, contents=prompt, config=config
            )
            return response, None
        except Exception as error:
            kind = error_kind(error)
            if kind == "quota":
                print("   Gemini quota is exhausted. Stopping; no immediate retries.")
                return None, "quota"
            if kind == "rate_limit":
                wait = 30 * (attempt + 1)
            elif kind == "temporary":
                wait = 15 * (attempt + 1)
            else:
                print(f"   API error: {error}")
                return None, "error"

            if attempt == max_retries - 1:
                print(f"   API still unavailable after {max_retries} attempts.")
                return None, kind
            print(f"   Temporary API issue ({kind}); retrying in {wait}s...")
            time.sleep(wait)

    return None, "error"


def main():
    parser = argparse.ArgumentParser(
        description="Estimate product prices and save progress after every item."
    )
    parser.add_argument("input", help="Input product JSON file")
    parser.add_argument("--out", default="products_priced.json")
    parser.add_argument("--model", default="gemini-3.1-flash-lite")
    parser.add_argument("--no-search", action="store_true")
    parser.add_argument("--refresh", action="store_true",
                        help="Re-estimate prices already marked as AI estimates")
    parser.add_argument("--resume", action="store_true",
                        help="Continue from the existing output file")
    parser.add_argument("--delay", type=float, default=3.0)
    args = parser.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        sys.exit("GEMINI_API_KEY is not set. Set it in this CMD window first.")

    if args.resume and os.path.exists(args.out):
        with open(args.out, encoding="utf-8") as file:
            items = json.load(file)
        print(f"Resuming from {args.out}")
    else:
        with open(args.input, encoding="utf-8") as file:
            items = json.load(file)
        save_json(args.out, items)

    if not isinstance(items, list):
        sys.exit("Input JSON must contain a list of product records.")

    from google import genai
    from google.genai import types
    client = genai.Client(api_key=api_key)

    done = failed = skipped = 0
    stopped_for_quota = False

    try:
        for index, record in enumerate(items, 1):
            manual_price = float(record.get("price") or 0) > 0 and not record.get("priceEstimated")
            existing_estimate = bool(record.get("priceEstimated")) and not args.refresh
            if manual_price or existing_estimate:
                skipped += 1
                continue

            name = record.get("name", f"Product {index}")
            print(f"[{index}/{len(items)}] {name}")

            prompt = PROMPT.format(
                name=name,
                barcode=record.get("barcode", ""),
                pack=record.get("packSize") or "not specified; infer only if clear from product name",
                category=record.get("category", ""),
            )

            response, status = ask_gemini(
                client, types, args.model, prompt, not args.no_search
            )

            if status == "quota":
                stopped_for_quota = True
                break

            estimate = parse_estimate(getattr(response, "text", None)) if response else None
            if estimate is None:
                print("   No valid estimate; price remains unset.")
                record["priceEstimationStatus"] = "failed"
                record["issues"] = list(record.get("issues", []))
                if "price estimation failed" not in record["issues"]:
                    record["issues"].append("price estimation failed")
                record["needsReview"] = True
                failed += 1
            else:
                sources = [] if args.no_search else grounding_sources(response)
                apply_estimate(record, estimate, sources, not args.no_search)
                record["priceEstimationStatus"] = "completed"
                print(
                    f"   PHP {estimate['min']:.2f}-{estimate['max']:.2f} "
                    f"(typical {estimate['typical']:.2f}, {estimate['confidence']})"
                )
                if args.no_search:
                    print("   Note: model-knowledge estimate only; verify manually.")
                elif not sources:
                    print("   Warning: no grounding sources returned; verify manually.")
                done += 1

            save_json(args.out, items)
            if args.delay > 0:
                time.sleep(args.delay)

    except KeyboardInterrupt:
        print("\nInterrupted by user. Saving completed work...")

    finally:
        save_json(args.out, items)

    print(f"\nThis run: estimated {done}, failed {failed}, skipped {skipped}.")
    print(f"Saved catalog: {args.out}")
    if stopped_for_quota:
        print("Stopped because Gemini quota was exhausted. Use --resume after quota is restored.")
    else:
        print("Review low-confidence estimates and verify prices against Philippine stores.")
    print("Do not upload until the catalog has been reviewed.")


if __name__ == "__main__":
    main()
