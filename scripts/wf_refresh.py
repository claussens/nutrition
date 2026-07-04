#!/usr/bin/env python3
"""
wf_refresh.py — reusable Whole Foods price + macro refresher for the
nutrition app's Ingredient seed.

WHY THIS EXISTS
---------------
Whole Foods serves price + full nutrition server-rendered into the
product page's `__NEXT_DATA__` JSON, keyed to the store pinned by the
`wfm_store_d8` cookie. The data path is bot-protected: plain curl /
URLSession (even with the store cookie) gets a stripped shell. A real
browser engine that executes JS establishes the protected session, so
this script drives headless Chromium via Playwright.

Store is pinned to Shane's store: San Mateo (id 10150 / SMT). Prices
change far more often than macros, so re-run this whenever you want
fresh numbers. Regular price is used, never the sale price
(regular = offerDetails.price.basisPriceAmount or .priceAmount when
not on sale).

USAGE
-----
  # one-time setup (isolated venv; system python3 here lacks pip)
  /Users/shane/.pyenv/versions/3.10.4/bin/python3 -m venv scripts/.venv
  scripts/.venv/bin/python -m pip install playwright
  scripts/.venv/bin/python -m playwright install chromium

  # dry run: fetch everything, write a review JSON, change nothing
  scripts/.venv/bin/python scripts/wf_refresh.py

  # apply ONLY prices (totalCost) back into Ingredient.swift
  scripts/.venv/bin/python scripts/wf_refresh.py --apply prices

  # apply price + macros (deferred until the Food-model redesign lands;
  # implemented but intentionally not the default)
  scripts/.venv/bin/python scripts/wf_refresh.py --apply full

Always fetches full data (price + macros) into scripts/wf_refresh_out.json
regardless of --apply scope, so the macro data is captured for later.
"""

import argparse
import base64
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(REPO, "nutrition", "Ingredients", "Ingredient.swift")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wf_refresh_out.json")

# ---------------------------------------------------------------------------
# Store config (Shane = San Mateo). Stable; edit here if the store changes.
# ---------------------------------------------------------------------------
STORE = {
    "id": "10150",
    "name": "San Mateo",
    "tlc": "SMT",
    "path": "sanmateo",
    "state": "CA",
    "lat": 37.543935,
    "lng": -122.291697,
}


def _b64(obj: dict) -> str:
    return base64.b64encode(json.dumps(obj, separators=(",", ":")).encode()).decode()


def store_cookies():
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    d8 = {
        "id": STORE["id"], "name": STORE["name"], "tlc": STORE["tlc"],
        "path": STORE["path"], "state": STORE["state"], "store_nid": "",
        "start_date": now, "updated_date": now,
        "geometry": {"coordinates": [STORE["lng"], STORE["lat"]], "type": "Point"},
    }
    weak = {
        "version": 1, "storeId": int(STORE["id"]),
        "geoCoordinate": {"latitude": STORE["lat"], "longitude": STORE["lng"],
                          "altitudeMeters": 0.0},
    }
    base = {"domain": ".wholefoodsmarket.com", "path": "/"}
    return [
        {**base, "name": "wfm_store_d8", "value": _b64(d8)},
        {**base, "name": "wfm_store_weak", "value": _b64(weak)},
    ]


# ---------------------------------------------------------------------------
# Parse Ingredient.swift into (name, url, asin, span) records.
# ---------------------------------------------------------------------------
APPEND = "ingredients.append(Ingredient("
NAME_RE = re.compile(r'name:\s*"((?:[^"\\]|\\.)*)"')
URL_RE = re.compile(r'url:\s*"(https://www\.wholefoodsmarket\.com/[^"]+)"')
ASIN_RE = re.compile(r'/([0-9a-z]{10})/?(?:\?|$)')
# WF product URLs are .../product/<slug>-<asin>[?...]; the ASIN is the
# trailing 10-char [0-9a-z] token of the path (preceded by '/' or '-').
ASIN_ANY_RE = re.compile(r'[/-]([0-9a-z]{10})(?:[/?#]|$)')


def asin_from_url(url):
    path = url.split("?")[0].rstrip("/")
    m = ASIN_ANY_RE.search(path + "?")
    return m.group(1) if m else path.rsplit("/", 1)[-1][:32]


def slug_from_url(url):
    return url.split("?")[0].rstrip("/").rsplit("/", 1)[-1]


def parse_seed(text):
    rows = []
    idx = 0
    while True:
        start = text.find(APPEND, idx)
        if start == -1:
            break
        nxt = text.find(APPEND, start + len(APPEND))
        end = nxt if nxt != -1 else text.find("\n    }", start)
        block = text[start:end if end != -1 else len(text)]
        nm = NAME_RE.search(block)
        um = URL_RE.search(block)
        if nm and um:
            # asin_from_url handles both plain (/b07fycb4wx) and
            # slug (fresh-produce-...-b000se9nug) WF URLs; the old
            # ASIN_RE missed slug URLs, silently excluding those
            # entries from the price refresh.
            rows.append({
                "name": nm.group(1),
                "url": um.group(1),
                "asin": asin_from_url(um.group(1)),
                "start": start,
                "end": start + len(block),
            })
        idx = start + len(APPEND)
    return rows


# ---------------------------------------------------------------------------
# Fetch via Playwright (real browser → passes bot protection).
# ---------------------------------------------------------------------------
def fetch_all(rows, headed=False):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        sys.exit("Playwright missing. Run: pip install playwright && "
                 "playwright install chromium")

    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=not headed)
        ctx = browser.new_context(
            user_agent=("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/124.0.0.0 Safari/537.36"))
        ctx.add_cookies(store_cookies())
        page = ctx.new_page()
        # Warm up once so bot-protection cookies (rxc/csm-hit) get set.
        page.goto("https://www.wholefoodsmarket.com/", timeout=45000)
        page.wait_for_timeout(1500)

        for i, r in enumerate(rows, 1):
            rec = {"name": r["name"], "asin": r["asin"], "url": r["url"]}
            try:
                page.goto(r["url"], timeout=45000, wait_until="domcontentloaded")
                nd = page.evaluate(
                    "() => { const e = document.getElementById('__NEXT_DATA__');"
                    " return e ? e.textContent : null; }")
                if not nd:
                    rec["error"] = "no __NEXT_DATA__ (bot-blocked or bad page)"
                else:
                    a = (json.loads(nd).get("props", {})
                         .get("pageProps", {}).get("aapiData") or {})
                    rec.update(parse_aapi(a))
            except Exception as e:  # noqa: BLE001 - report, keep going
                rec["error"] = f"{type(e).__name__}: {e}"
            results.append(rec)
            print(f"[{i}/{len(rows)}] {r['name']}: "
                  f"{rec.get('regularPrice', rec.get('error'))}",
                  file=sys.stderr)
            page.wait_for_timeout(900)  # be polite
        browser.close()
    return results


def parse_aapi(a):
    od = (a.get("offerDetails") or {})
    price = od.get("price") or {}
    cur = price.get("priceAmount")
    basis = price.get("basisPriceAmount")  # set only when on sale
    on_sale = basis is not None
    regular = basis if on_sale else cur
    nf = a.get("nutritionFacts") or {}
    return {
        "name_wf": a.get("name"),
        "brand": a.get("brandName"),
        "regularPrice": regular,
        "currentPrice": cur,
        "onSale": on_sale,
        "unitPrice": od.get("unitPrice"),
        "calories": nf.get("caloriesAmount"),
        "servingSize": nf.get("servingSize"),
        "servingsPerContainer": nf.get("servingsPerContainer"),
        "macronutrients": nf.get("macronutrients"),
        "vitaminsAndMinerals": nf.get("vitaminsAndMinerals"),
    }


# ---------------------------------------------------------------------------
# Apply back into Ingredient.swift.
# ---------------------------------------------------------------------------
TOTALCOST_RE = re.compile(r'(\n\s*)totalCost:\s*[0-9.]+\s*,')
URL_LINE_RE = re.compile(r'(\n(\s*))url:\s*"https://www\.wholefoodsmarket\.com/[^"]+",')


def apply_prices(text, rows, results):
    by_asin = {r["asin"]: r for r in results}
    changes = []
    # Apply from the bottom up so earlier spans stay valid.
    for r in sorted(rows, key=lambda x: x["start"], reverse=True):
        res = by_asin.get(r["asin"])
        if not res or res.get("regularPrice") is None:
            continue
        price = float(res["regularPrice"])
        block = text[r["start"]:r["end"]]
        m = TOTALCOST_RE.search(block)
        if m:
            old = re.search(r'[0-9.]+', m.group(0)).group(0)
            if abs(float(old) - price) < 1e-9:
                continue
            new_block = TOTALCOST_RE.sub(
                lambda mm: f'{mm.group(1)}totalCost: {price:g},', block, count=1)
            changes.append((r["name"], old, f"{price:g}"))
        else:
            um = URL_LINE_RE.search(block)
            if not um:
                continue
            indent = um.group(2)
            ins = um.group(0) + f'\n{indent}totalCost: {price:g},'
            new_block = block.replace(um.group(0), ins, 1)
            changes.append((r["name"], "—", f"{price:g}"))
        text = text[:r["start"]] + new_block + text[r["end"]:]
    return text, changes


def main():
    ap = argparse.ArgumentParser(description="Refresh WF prices/macros.")
    ap.add_argument("--apply", choices=["prices", "full"], default=None,
                    help="Patch Ingredient.swift. Default: dry run only.")
    ap.add_argument("--headed", action="store_true",
                    help="Show the browser (debugging).")
    ap.add_argument("--limit", type=int, default=0,
                    help="Only the first N entries (smoke test).")
    ap.add_argument("--url", nargs="+", metavar="URL", default=None,
                    help="Fetch one or more WF product URLs directly "
                         "(ignores the seed and wf_refresh_out.json). "
                         "Prints parsed price + nutrition as JSON.")
    args = ap.parse_args()

    # ---- single / small-set URL mode -------------------------------
    # No seed parse, no cache read/write. Use this to look up an
    # individual product (e.g. before adding a new Ingredient).
    if args.url:
        rows = [{"name": slug_from_url(u), "url": u,
                 "asin": asin_from_url(u)} for u in args.url]
        results = fetch_all(rows, headed=args.headed)
        print(json.dumps(results, indent=2))
        return

    text = open(SEED, encoding="utf-8").read()
    rows = parse_seed(text)
    if not rows:
        sys.exit("seed data moved to ../nutrition-config/*.yaml; this script "
                 "is obsolete — use the nutrition-plugin wholefoods tooling "
                 "instead")
    if args.limit:
        rows = rows[:args.limit]
    print(f"{len(rows)} Ingredient entries carry a Whole Foods URL.")

    results = fetch_all(rows, headed=args.headed)
    json.dump(results, open(OUT, "w"), indent=2)
    ok = [r for r in results if r.get("regularPrice") is not None]
    sale = [r for r in results if r.get("onSale")]
    print(f"\nfetched: {len(ok)}/{len(results)} priced; "
          f"{len(sale)} were on sale (regular price used). -> {OUT}")

    if args.apply == "full":
        sys.exit("--apply full not enabled yet (deferred until the "
                 "Food-model redesign settles variant/foodName shape).")
    if args.apply == "prices":
        new_text, changes = apply_prices(text, rows, results)
        if changes:
            open(SEED + ".bak", "w", encoding="utf-8").write(text)
            open(SEED, "w", encoding="utf-8").write(new_text)
        print(f"\napplied totalCost to {len(changes)} entries "
              f"(.bak written):")
        for nm, old, new in changes:
            print(f"  {nm}: {old} -> {new}")


if __name__ == "__main__":
    main()
