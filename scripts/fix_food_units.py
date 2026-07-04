#!/usr/bin/env python3
"""
fix_food_units.py — correct the consumption-unit data regression.

PROBLEM: the Whole Foods enrichment created brand-variant Ingredients
with consumptionUnit=.gram / consumptionGrams=1 (wrong — you eat
Coconut Oil in tbsp, Eggs as eggs, regardless of brand). Each Food's
default points at such a variant, so meal rows show grams with broken
amount semantics.

FIX: consumption unit is a property of the FOOD, not the brand. For
each Food, take the canonical member's (the Ingredient whose `name`
== its `foodName`) consumptionUnit + consumptionGrams and apply them
to EVERY member of that Food. servingSize and price are left alone
(those are genuinely per-variant; price/weight is handled separately).

Usage:
  python3 scripts/fix_food_units.py            # dry run (report only)
  python3 scripts/fix_food_units.py --apply    # rewrite Ingredient.swift
"""
import re
import sys
import os

SEED = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "nutrition", "Ingredients", "Ingredient.swift")

APPEND = "ingredients.append(Ingredient("
NAME_RE = re.compile(r'name:\s*"((?:[^"\\]|\\.)*)"')
FOOD_RE = re.compile(r'foodName:\s*"((?:[^"\\]|\\.)*)"')
UNIT_RE = re.compile(r'consumptionUnit:\s*Unit\.(\w+)')
CG_RE = re.compile(r'consumptionGrams:\s*([0-9.]+)')


def blocks(text):
    out, i = [], 0
    while True:
        s = text.find(APPEND, i)
        if s == -1:
            break
        nxt = text.find(APPEND, s + len(APPEND))
        e = nxt if nxt != -1 else text.find("\n    }", s)
        out.append((s, (e if e != -1 else len(text))))
        i = s + len(APPEND)
    return out


def parse(text):
    rows = []
    for s, e in blocks(text):
        blk = text[s:e]
        nm, fn = NAME_RE.search(blk), FOOD_RE.search(blk)
        if not nm or not fn:
            continue
        u, cg = UNIT_RE.search(blk), CG_RE.search(blk)
        rows.append({
            "s": s, "e": e, "name": nm.group(1), "food": fn.group(1),
            "unit": u.group(1) if u else None,
            "cg": cg.group(1) if cg else None,
        })
    return rows


def main():
    apply = "--apply" in sys.argv
    text = open(SEED, encoding="utf-8").read()
    rows = parse(text)
    if not rows:
        sys.exit("seed data moved to ../nutrition-config/*.yaml; this script "
                 "is obsolete — use the nutrition-plugin wholefoods tooling "
                 "instead")

    by_food = {}
    for r in rows:
        by_food.setdefault(r["food"], []).append(r)

    canon = {}        # food -> (unit, cg) from the canonical member
    no_canon = []     # foods with no name==foodName member
    for food, members in by_food.items():
        c = next((m for m in members if m["name"] == food), None)
        if c and c["unit"] and c["cg"]:
            canon[food] = (c["unit"], c["cg"])
        else:
            no_canon.append(food)

    edits = []  # (s, e, newblock, name, oldunit->newunit)
    for r in rows:
        tgt = canon.get(r["food"])
        if not tgt:
            continue
        u, cg = tgt
        if r["unit"] == u and r["cg"] == cg:
            continue
        blk = text[r["s"]:r["e"]]
        nb = blk
        if UNIT_RE.search(nb):
            nb = UNIT_RE.sub(f"consumptionUnit: Unit.{u}", nb, count=1)
        if CG_RE.search(nb):
            nb = CG_RE.sub(f"consumptionGrams: {cg}", nb, count=1)
        if nb != blk:
            edits.append((r["s"], r["e"], nb, r["name"],
                          f"{r['unit']}/{r['cg']} -> {u}/{cg}"))

    print(f"Foods: {len(by_food)} | canonical found: {len(canon)} | "
          f"NO canonical: {len(no_canon)}")
    if no_canon:
        print("  Foods lacking a canonical member (NOT auto-fixed — handle "
              "manually):")
        for f in sorted(no_canon):
            print(f"    - {f}: members = "
                  f"{[m['name'] for m in by_food[f]]}")
    print(f"\nVariants to re-unit: {len(edits)}")
    for s, e, nb, name, chg in edits[:40]:
        print(f"  {name}: {chg}")
    if len(edits) > 40:
        print(f"  ... +{len(edits)-40} more")

    if apply and edits:
        for s, e, nb, name, chg in sorted(edits, key=lambda t: t[0],
                                          reverse=True):
            text = text[:s] + nb + text[e:]
        open(SEED + ".units.bak", "w", encoding="utf-8").write(
            open(SEED, encoding="utf-8").read())
        open(SEED, "w", encoding="utf-8").write(text)
        print(f"\nAPPLIED {len(edits)} edits (.units.bak written).")
    elif apply:
        print("\nnothing to apply.")
    else:
        print("\n(dry run — pass --apply to write)")


if __name__ == "__main__":
    main()
