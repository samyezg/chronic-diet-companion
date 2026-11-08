# -*- coding: utf-8 -*-
"""
候选池确认脚本骨架：校验 text_candidate_pool.json
- 字段完整、灯色白名单
- 同病种内异写冲突（同 canonical 不同 light）标记需人工
用法: python _confirm_text_candidates.py [--promote]  # --promote 将 status=approved 提示（正式写入映射需人工）
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POOL = os.path.join(HERE, "text_candidate_pool.json")
VALID = ("红灯", "黄灯", "绿灯")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--promote", action="store_true", help="打印已 approved 条目（不自动改映射表）")
    args = ap.parse_args()

    if not os.path.isfile(POOL):
        print("无候选池文件:", POOL)
        return 0
    with open(POOL, encoding="utf-8") as f:
        pool = json.load(f)
    cands = pool.get("candidates") or []
    errors = []
    by_canon = {}
    for i, c in enumerate(cands):
        for k in ("disease", "raw_name", "canonical_name", "light"):
            if not c.get(k):
                errors.append("#%d 缺字段 %s" % (i, k))
        if c.get("light") not in VALID:
            errors.append("#%d light 非法: %s" % (i, c.get("light")))
        key = "%s|%s" % (c.get("disease"), c.get("canonical_name"))
        by_canon.setdefault(key, []).append(c)

    conflicts = []
    for key, group in by_canon.items():
        lights = set(g.get("light") for g in group)
        if len(lights) > 1:
            conflicts.append((key, sorted(lights), [g.get("raw_name") for g in group]))

    print("candidates=%d errors=%d conflicts=%d" % (len(cands), len(errors), len(conflicts)))
    for e in errors:
        print("ERR", e)
    for key, lights, raws in conflicts:
        print("CONFLICT", key, lights, "raws=", raws, "→ 需人工")

    pending = [c for c in cands if c.get("status") == "pending"]
    approved = [c for c in cands if c.get("status") == "approved"]
    print("pending=%d approved=%d" % (len(pending), len(approved)))
    if args.promote:
        for c in approved:
            print("PROMOTE", json.dumps(c, ensure_ascii=False))
        print("提示：请人工将 approved 条目补入对应 vision_dish_mapping_* 后重跑 _gen 脚本")
    return 1 if errors or conflicts else 0


if __name__ == "__main__":
    sys.exit(main())
