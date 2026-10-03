# 🧪 Lab Sheet — Networking Day 05: nmap Part 2 (Scan Types, Timing & Port Ranges)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Targets allowed:** `localhost` (127.0.0.1), your own local subnet, `scanme.nmap.org`. Nothing else.

---

## Part A: TCP SYN scan vs TCP Connect scan

```bash
# A1 - SYN scan (the nmap default when run as root/sudo) - "half-open", stealthier
sudo nmap -sS scanme.nmap.org

# A2 - full TCP Connect scan - completes the full handshake, works without root
nmap -sT scanme.nmap.org
```
📸 Screenshot: `01-syn-vs-connect.png`

**Note down:**
- Did both scans find the same open ports?
- Which one needed `sudo` and which didn't?

---

## Part B: UDP scan (slower, different protocol entirely)

```bash
# B1 - UDP scan on a SMALL set of common UDP ports only (full UDP scan is very slow)
sudo nmap -sU -p 53,67,123,161 scanme.nmap.org
```
📸 Screenshot: `02-udp-scan.png`

**Note down:**
- UDP scans often show `open|filtered` instead of a clean `open`. Did you see that here? Why do you think UDP results are less certain than TCP results?

---

## Part C: timing templates — the speed/stealth tradeoff

```bash
# C1 - slow and polite (T2)
nmap -T2 -F scanme.nmap.org

# C2 - fast and aggressive (T4) - you already tried this on Day 04, run it again for comparison
nmap -T4 -F scanme.nmap.org

# C3 - compare: use 'time' to measure how long each actually took
time nmap -T2 -F scanme.nmap.org
time nmap -T4 -F scanme.nmap.org
```
📸 Screenshot: `03-timing-comparison.png`

**Note down:**
- How much of a time difference was there between T2 and T4?
- Why might a real attacker deliberately choose a SLOWER timing template (like T1 or T2) on a real target?

---

## Part D: port specification, review and extend

```bash
# D1 - specific list of ports
nmap -p 21,22,25,80,443 scanme.nmap.org

# D2 - a range combined with a list
nmap -p 1-50,80,443,8080 scanme.nmap.org

# D3 - only scan the TOP N most common ports (an alternative to -F)
nmap --top-ports 20 scanme.nmap.org
```
📸 Screenshot: `04-port-specification.png`

**Note down:**
- Did `--top-ports 20` return a different result than `-F` (top 100)?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
