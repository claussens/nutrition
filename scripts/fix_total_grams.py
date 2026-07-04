#!/usr/bin/env python3
"""
fix_total_grams.py — give every priced ingredient a real net weight.

PROBLEM: many priced ingredients have totalCost but totalGrams == 0
(or missing). Cost is totalCost / totalGrams, so the daily total
silently drops them to $0 while the detail screen name-guesses a
weight — inconsistent and wrong (e.g. Coconut Oil).

FIX: compute each priced product's true package weight in grams and
write it to `totalGrams`, using, in priority order:
  1. label: servingsPerContainer x grams-per-serving (from the
     captured Whole Foods nutrition panel) — exact when the panel
     gives a gram serving size.
  2. Whole Foods unit price: packageSize = totalCost / pricePerUnit,
     converted by baseUnit (lb / oz exact; fluid-ounce via density;
     count x per-unit grams).
  3. parse the size out of the product name (lb/oz/fl oz/count/g) —
     same heuristic the app's effectiveTotalGrams already trusts.

Data source: scripts/wf_refresh_out.json (already captured; no
re-fetch). Matches the seed by ingredient name.

Usage:
  python3 scripts/fix_total_grams.py            # dry run
  python3 scripts/fix_total_grams.py --apply    # write Ingredient.swift
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(REPO, "nutrition", "Ingredients", "Ingredient.swift")
WF = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                  "wf_refresh_out.json")

OZ_G = 28.349523
LB_G = 453.59237
FLOZ_ML = 29.57353

APPEND = "ingredients.append(Ingredient("
NAME_RE = re.compile(r'name:\s*"((?:[^"\\]|\\.)*)"')
COST_RE = re.compile(r'totalCost:\s*([0-9.]+)')
GRAMS_RE = re.compile(r'totalGrams:\s*([0-9.]+)')
COST_LINE_RE = re.compile(r'(\n(\s*))totalCost:\s*[0-9.]+\s*,')


def serving_grams(s):
    if not s:
        return None
    m = re.search(r'\(?\s*([0-9.]+)\s*g\b', str(s))
    return float(m.group(1)) if m else None


def spc_num(s):
    if not s:
        return None
    m = re.search(r'([0-9.]+)', str(s))
    return float(m.group(1)) if m else None


def density_for(name):
    n = name.lower()
    if "oil" in n:
        return 0.918          # vegetable/coconut/olive oils
    return 1.0                # condiments/liquids ~ water


def from_name(name):
    s = name.lower()

    def num(pat):
        m = re.search(pat, s)
        return float(m.group(1)) if m else None
    n = num(r'([0-9]+(?:\.[0-9]+)?)\s*fl\s*oz')
    if n:
        return n * FLOZ_ML * density_for(name)
    n = num(r'([0-9]+(?:\.[0-9]+)?)\s*(?:oz|ounce|ounces)\b')
    if n:
        return n * OZ_G
    n = num(r'([0-9]+(?:\.[0-9]+)?)\s*(?:lb|lbs|pound|pounds)\b')
    if n:
        return n * LB_G
    n = num(r'([0-9]+(?:\.[0-9]+)?)\s*pint')
    if n:
        return n * 473.176
    return None


def derive(rec, name, cost, serv_g):
    """Return (grams, method) or (None, reason)."""
    # 1. label: servings/container x grams/serving
    g = serving_grams(rec.get("servingSize")) if rec else None
    spc = spc_num(rec.get("servingsPerContainer")) if rec else None
    if g and spc:
        return round(g * spc, 1), "label spc*serv"
    # 2. WF unit price
    up = (rec or {}).get("unitPrice") or {}
    pa = up.get("priceAmount")
    bu = (up.get("baseUnit") or "").lower()
    if pa and cost:
        size = cost / pa
        if bu in ("lb", "pound"):
            return round(size * LB_G, 1), "unitprice lb"
        if bu in ("ounce", "oz"):
            return round(size * OZ_G, 1), "unitprice oz"
        if bu in ("fluid ounce", "fl oz"):
            return round(size * FLOZ_ML * density_for(name), 1), \
                "unitprice floz"
        if bu == "count":
            per = serving_grams(rec.get("servingSize")) or serv_g
            if per:
                return round(round(size) * per, 1), "unitprice count"
    # 3. parse from name
    n = from_name(name)
    if n:
        return round(n, 1), "name parse"
    return None, "UNRESOLVED"


def main():
    apply = "--apply" in sys.argv
    text = open(SEED, encoding="utf-8").read()
    if APPEND not in text:
        sys.exit("seed data moved to ../nutrition-config/*.yaml; this script "
                 "is obsolete — use the nutrition-plugin wholefoods tooling "
                 "instead")
    wf = {r["name"]: r for r in json.load(open(WF))}

    edits, unresolved = [], []
    i = 0
    while True:
        s = text.find(APPEND, i)
        if s == -1:
            break
        nxt = text.find(APPEND, s + len(APPEND))
        e = nxt if nxt != -1 else text.find("\n    }", s)
        e = e if e != -1 else len(text)
        blk = text[s:e]
        i = s + len(APPEND)
        nm = NAME_RE.search(blk)
        cm = COST_RE.search(blk)
        if not nm or not cm:
            continue
        name = nm.group(1)
        cost = float(cm.group(1))
        gm = GRAMS_RE.search(blk)
        cur = float(gm.group(1)) if gm else 0.0
        if cur > 0:
            continue                       # already has a weight
        sv = re.search(r'servingSize:\s*([0-9.]+)', blk)
        serv_g = float(sv.group(1)) if sv else None
        grams, how = derive(wf.get(name), name, cost, serv_g)
        if not grams:
            unresolved.append((name, cost))
            continue
        cl = COST_LINE_RE.search(blk)
        if not cl:
            unresolved.append((name + " (no totalCost line)", cost))
            continue
        indent = cl.group(2)
        newblk = blk.replace(
            cl.group(0),
            cl.group(0) + f'\n{indent}totalGrams: {grams},', 1)
        edits.append((s, e, newblk, name, cost, grams, how))

    print(f"priced items needing a weight: {len(edits)+len(unresolved)}")
    for s, e, nb, name, cost, grams, how in edits:
        print(f"  {name[:46]:46} ${cost:<6} -> {grams:>8} g  [{how}]")
    if unresolved:
        print("UNRESOLVED (need manual weight):")
        for name, cost in unresolved:
            print(f"  {name} (${cost})")

    if apply and edits:
        for s, e, nb, *_ in sorted(edits, key=lambda t: t[0],
                                   reverse=True):
            text = text[:s] + nb + text[e:]
        open(SEED + ".grams.bak", "w", encoding="utf-8").write(
            open(SEED, encoding="utf-8").read())
        open(SEED, "w", encoding="utf-8").write(text)
        print(f"\nAPPLIED {len(edits)} totalGrams (.grams.bak written).")
    elif not apply:
        print("\n(dry run — pass --apply to write)")


if __name__ == "__main__":
    main()
