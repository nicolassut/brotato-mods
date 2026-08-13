"""Merge community-sentiment ratings into the P2W rarity spread draft.

Input: text files of lines "ITEM NAME | rating | evidence" (rating S/A/B/C/D)
from the research agents, one file per source. Items are matched to
rarity_spread.json by normalized name; unmatched lines are reported, never
silently dropped.

Consensus: majority rating across sources (ties -> the stronger rating).
Proposed rung = home rung of the item's vanilla tier + offset(S:+2 A:+1 B:0
C:-1 D:-2), clamped to [1, 8]. Items with no sentiment keep their value-based
draft rung. Output: proposals.json + a human-readable diff on stdout.
Nothing is applied to rarity_spread.json here - that happens only after user
approval (apply --write).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPREAD = os.path.join(HERE, "rarity_spread.json")
HOME_RUNG = {0: 1, 1: 3, 2: 5, 3: 6}
OFFSET = {"S": 2, "A": 1, "B": 0, "C": -1, "D": -2}
RANK = {"S": 4, "A": 3, "B": 2, "C": 1, "D": 0}
RUNG_NAME = {1: "White", 2: "Green", 3: "Blue", 4: "Teal",
             5: "Purple", 6: "Red", 7: "Pink", 8: "Gold"}


def norm(s):
    s = s.lower().replace("'s", "").replace("’s", "")
    return re.sub(r"[^a-z0-9]+", "", s)


# the mod converted these vanilla items into foods and shipped stat-identical
# replacement items - donor sentiment transfers to the clone (normalized names)
ALIASES = {"coffee": "alarmclock", "cake": "partyballoon",
           "freshmeat": "mosquitojar", "honey": "stickybomb"}


def load_sentiment(paths):
    by_item = {}
    bad = []
    for p in paths:
        src = os.path.basename(p)
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line or "|" not in line:
                continue
            parts = [x.strip() for x in line.split("|")]
            if len(parts) < 2 or parts[1][:1].upper() not in RANK:
                bad.append((src, line[:60]))
                continue
            key = norm(parts[0])
            key = ALIASES.get(key, key)
            by_item.setdefault(key, []).append(
                (parts[1][:1].upper(), parts[2] if len(parts) > 2 else "", src, parts[0]))
    return by_item, bad


def consensus(votes):
    # median across sources: one enthusiastic outlier can't drag an item's rating
    ranks = sorted(RANK[v[0]] for v in votes)
    med = ranks[len(ranks) // 2] if len(ranks) % 2 else ranks[len(ranks) // 2 - 1]
    return {v: k for k, v in RANK.items()}[med]


def main():
    write = "--write" in sys.argv
    paths = [a for a in sys.argv[1:] if not a.startswith("--")]
    spread = json.load(open(SPREAD))
    items = spread["items"]
    sent, bad = load_sentiment(paths)
    by_norm = {norm(v["name"]): k for k, v in items.items()}

    proposals, unmatched = [], []
    for n, votes in sent.items():
        if n not in by_norm:
            unmatched.append(votes[0][3])
            continue
        my_id = by_norm[n]
        it = items[my_id]
        if it.get("hand"):
            continue  # user hand-placement always wins over sentiment
        rating = consensus(votes)
        if rating == "B":
            continue  # "it's fine" is not a reason to fight the price draft
        # price is the primary measure (user rule 2026-08-10): sentiment gives a
        # DIRECTION, and an item moves at most ONE rung from its value-draft spot,
        # only when sentiment clearly disagrees with where it sits. Tardigrade law:
        # a beloved epic stays ~5-6, never jumps to pink/gold.
        target = max(1, min(8, HOME_RUNG[it["tier"]] + OFFSET[rating]))
        if target == it["rung"]:
            continue
        step = 1 if target > it["rung"] else -1
        proposed = it["rung"] + step
        if proposed != it["rung"]:
            proposals.append({
                "my_id": my_id, "name": it["name"], "tier": it["tier"],
                "from": it["rung"], "to": proposed, "rating": rating,
                "votes": [f"{r}({s.split('.')[0]}): {e}" for r, e, s, _ in votes],
            })

    proposals.sort(key=lambda p: (p["to"] - p["from"]), reverse=True)
    json.dump({"proposals": proposals, "unmatched": unmatched},
              open(os.path.join(HERE, "sentiment_proposals.json"), "w"), indent=1)

    print(f"sentiment on {len(sent)} names, matched {len(sent) - len(unmatched)}, "
          f"{len(proposals)} rung changes proposed, {len(bad)} bad lines")
    for p in proposals:
        d = p["to"] - p["from"]
        arrow = "UP" if d > 0 else "dn"
        print(f"  {arrow}{abs(d)} {p['name']:<26} {RUNG_NAME[p['from']]:>6} -> "
              f"{RUNG_NAME[p['to']]:<6} [{p['rating']}] {p['votes'][0][:70]}")
    if unmatched:
        print("unmatched names:", ", ".join(sorted(set(unmatched))[:40]))

    if write:
        for p in proposals:
            items[p["my_id"]]["rung"] = p["to"]
            items[p["my_id"]]["sentiment"] = p["rating"]
        json.dump(spread, open(SPREAD, "w"), indent=1)
        print(f"APPLIED {len(proposals)} moves to rarity_spread.json")


if __name__ == "__main__":
    main()
