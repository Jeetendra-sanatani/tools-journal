# 🧪 Lab Sheet — Networking Day 06: nmap Part 3 (Service & OS Detection)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Targets allowed:** `localhost` (127.0.0.1), your own local subnet, `scanme.nmap.org`. Nothing else.

**Heads up from Day 05:** `-sS` was extremely slow against scanme.nmap.org that day. If a scan here seems stuck for several minutes, it's fine to Ctrl+Z it (and this time, follow up with `kill %1` to actually end the suspended job) and just note that it happened — slow responses from a shared public target are a normal, expected result, not something to fight through.

---

## Part A: service/version detection

```bash
# A1 - service version detection on your own machine (fast, safe)
nmap -sV 127.0.0.1

# A2 - same, against scanme.nmap.org
nmap -sV scanme.nmap.org

# A3 - intensity control: lower = faster but less accurate, higher = slower but more thorough
nmap -sV --version-intensity 2 scanme.nmap.org
```
📸 Screenshot: `01-service-detection.png`

**Note down:**
- What extra information did `-sV` show compared to a plain scan (think back to Day 04)?
- Did lowering the intensity (A3) change the results or just the speed?

---

## Part B: OS detection

```bash
# B1 - OS detection on your own machine (needs sudo)
sudo nmap -O 127.0.0.1

# B2 - OS detection against scanme.nmap.org
sudo nmap -O scanme.nmap.org
```
📸 Screenshot: `02-os-detection.png`

**Note down:**
- Did nmap give a confident OS guess, or did it show percentages/multiple possibilities?
- OS detection relies on subtle quirks in how a system responds to probes — why do you think this is called a "guess" rather than a certainty?

---

## Part C: combining it all — the "everything" scan

```bash
# C1 - -A turns on OS detection, version detection, script scanning, and traceroute all at once
sudo nmap -A -p 22,80 scanme.nmap.org
```
📸 Screenshot: `03-aggressive-scan.png`

**Note down:**
- How much MORE information did `-A` give you compared to a basic `-sV` or `-O` alone?
- `-A` is thorough but noisy/slow — when would you NOT want to use it?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected (including if you had to suspend/kill a slow scan again)

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
