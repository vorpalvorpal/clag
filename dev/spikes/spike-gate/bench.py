#!/usr/bin/env python3
"""bench.py N label 'shell command'  -- run N times (after one untimed warm-up unless WARM=0), print+append median/min/max wall seconds."""
import subprocess, sys, time, statistics, os, json
n = int(sys.argv[1]); label = sys.argv[2]; cmd = sys.argv[3]
setup = os.environ.get("SETUP")           # optional shell command run (untimed) before each run
def run():
    if setup: subprocess.run(setup, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t = time.perf_counter()
    r = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    d = time.perf_counter() - t
    if r.returncode != 0: sys.stderr.write("FAILED (%d): %s\n%s\n" % (r.returncode, cmd, r.stderr.decode()[-500:]))
    for line in r.stderr.decode().splitlines():
        if line.startswith("files="):
            for kv in line.split("|")[1].split():
                k, v = kv.split("="); steps.setdefault(k, []).append(float(v))
    return d
steps = {}
load0 = round(os.getloadavg()[0], 1)
if os.environ.get("WARM", "1") == "1": run()
steps.clear()
ts = [run() for _ in range(n)]
med_steps = {k: round(statistics.median(v), 3) for k, v in steps.items()}
rec = dict(load1_before=load0, load1_after=round(os.getloadavg()[0], 1), steps=med_steps, label=label, n=n, median=round(statistics.median(ts), 4), min=round(min(ts), 4), max=round(max(ts), 4), cmd=cmd)
print("%-58s median %.3fs  (min %.3f, max %.3f)" % (label, rec["median"], rec["min"], rec["max"]) + "  [load1 %s->%s]" % (load0, rec["load1_after"]) + ("\n      steps(median s): " + " ".join("%s=%s" % kv for kv in med_steps.items()) if med_steps else ""))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "timing.jsonl"), "a") as f: f.write(json.dumps(rec) + "\n")
