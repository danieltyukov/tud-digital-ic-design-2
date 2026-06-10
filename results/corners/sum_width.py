#!/usr/bin/env python3
"""Sum transistor widths (sigma-W) of the TDC core from the spectre netlist.

Counts everything under subckt tdc_core (the design surface), splitting
active devices from MOSCAP-connected ones (drain==source==bulk = trim caps).
Testbench blocks (TDC_in, TDC_out, POWER, wrapper sources) are excluded.
"""
import re
import sys
from collections import defaultdict

NETLIST = "/tmp/flat_netlist.txt"
TOP = sys.argv[1] if len(sys.argv) > 1 else "tdc_core"

# tuned design-variable values (TB_TDC maestro state, teammate's run)
VARS = {
    "m1_t1": 5, "m1_t2": 5, "m2_t1": 6, "m2_t2": 6, "fixt": 7,
    "m_inv_in": 10, "m_inv_out": 10,
    "trim0": 2, "trim1": 20, "trim2": 21, "fine": 18,
    "trim0_t2": 2, "trim1_t2": 14, "trim2_t2": 18,
}

SUFFIX = {"f": 1e-15, "p": 1e-12, "n": 1e-9, "u": 1e-6, "m": 1e-3}


def to_num(tok):
    tok = tok.strip()
    m = re.fullmatch(r"([-+0-9.eE]+)([fpnum]?)", tok)
    if not m:
        return None
    return float(m.group(1)) * SUFFIX.get(m.group(2), 1.0)


def eval_w(expr):
    """Evaluate a w= expression: plain number w/ suffix, or num*var."""
    parts = expr.split("*")
    val = 1.0
    for p in parts:
        n = to_num(p)
        if n is None:
            if p not in VARS:
                raise ValueError("unknown var in w expr: " + p)
            n = float(VARS[p])
        val *= n
    return val


def parse_subckts(path):
    subckts = {}
    cur, body = None, []
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            s = line.strip()
            if s.startswith("subckt "):
                cur = s.split()[1]
                body = []
            elif s.startswith("ends ") and cur:
                subckts[cur] = body
                cur = None
            elif cur is not None and s and not s.startswith("//"):
                body.append(s)
    return subckts


INST_RE = re.compile(r"^(\S+)\s+\(([^)]*)\)\s+(\S+)\s*(.*)$")


def walk(subckts, name, mult, acc, percell):
    for line in subckts.get(name, []):
        m = INST_RE.match(line)
        if not m:
            continue
        iname, nodes, master, params = m.groups()
        if master in ("nch", "pch"):
            wm = re.search(r"\bw=(\S+)", params)
            w = eval_w(wm.group(1)) * mult
            terms = nodes.split()
            is_cap = len(terms) == 4 and terms[0] == terms[2] == terms[3]
            kind = "moscap" if is_cap else "active"
            acc[(master, kind)] += w
            acc[("count", kind)] += mult
            percell[name][(master, kind)] += w
        elif master in subckts:
            im = re.search(r"\bm=(\S+)", params)
            k = int(float(im.group(1))) if im else 1
            walk(subckts, master, mult * k, acc, percell)
    return acc


def main():
    subckts = parse_subckts(NETLIST)
    acc = defaultdict(float)
    percell = defaultdict(lambda: defaultdict(float))
    walk(subckts, TOP, 1, acc, percell)

    act = acc[("nch", "active")] + acc[("pch", "active")]
    cap = acc[("nch", "moscap")] + acc[("pch", "moscap")]
    print("SIGMA-W report for subckt '%s' (vars: tuned maestro values)" % TOP)
    print("  active  NMOS W : %8.2f um" % (acc[("nch", "active")] * 1e6))
    print("  active  PMOS W : %8.2f um" % (acc[("pch", "active")] * 1e6))
    print("  active  total  : %8.2f um  (%d devices)"
          % (act * 1e6, acc[("count", "active")]))
    print("  MOSCAP  total  : %8.2f um  (%d devices, trim banks)"
          % (cap * 1e6, acc[("count", "moscap")]))
    print("  GRAND   total  : %8.2f um  (%d transistors)"
          % ((act + cap) * 1e6, acc[("count", "active")] + acc[("count", "moscap")]))
    print("\nPer-cell totals (um, summed over all instantiations):")
    for cell in sorted(percell):
        t = sum(percell[cell].values())
        print("  %-12s %8.2f" % (cell, t * 1e6))
    print("SIGMAW_DONE")


if __name__ == "__main__":
    sys.exit(main())
