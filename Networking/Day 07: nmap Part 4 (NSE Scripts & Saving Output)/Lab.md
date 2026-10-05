# 🧪 Lab Sheet — Networking Day 07: nmap Part 4 (NSE Scripts & Saving Output)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Targets allowed:** `localhost` (127.0.0.1), your own local subnet, `scanme.nmap.org`. Nothing else.

**Heads up:** scanme.nmap.org has been slow/rate-limited a few times already this week with heavier scans. If something here takes a long time, Ctrl+Z it, `kill %1` it properly, and just note what happened — that's a valid result, not a failure.

---

## Part A: NSE (Nmap Scripting Engine) basics

```bash
# A1 - the default safe script set, combined with version detection
nmap -sV -sC -p 22,80 scanme.nmap.org

# A2 - run ONE specific script by name (banner grabbing)
nmap --script=banner -p 22 scanme.nmap.org

# A3 - run a specific HTTP-related script
nmap --script=http-title -p 80 scanme.nmap.org

# A4 - see what script categories exist (just list them, don't run anything)
ls /usr/share/nmap/scripts/ | grep -i http | head -10
```
📸 Screenshot: `01-nse-basics.png`

**Note down:**
- What extra info did `-sC` add that plain `-sV` didn't show on Day 06?
- What did `http-title` return — an actual page title?

---

## Part B: saving scan output in different formats

```bash
# B1 - normal output, saved to a file
nmap -sV -p 22,80 scanme.nmap.org -oN scan_normal.txt

# B2 - XML output (used by other tools to parse nmap results programmatically)
nmap -sV -p 22,80 scanme.nmap.org -oX scan_output.xml

# B3 - all formats at once (normal + XML + grepable)
nmap -sV -p 22,80 scanme.nmap.org -oA scan_all

# B4 - look at what got created
ls -lh scan_normal.txt scan_output.xml scan_all.*
cat scan_normal.txt
```
📸 Screenshot: `02-saving-output.png`

**Note down:**
- How many files did `-oA` create, and what are their extensions?
- Open `scan_output.xml` briefly (`cat scan_output.xml | head -20`) — does it look readable to you, or clearly meant for another program to parse?

---

## Part C: a practical combined scan (tying Days 04-07 together)

```bash
# C1 - a "real" recon-style scan: top ports, version detection, default scripts, saved output
nmap -sV -sC -F scanme.nmap.org -oN final_recon.txt
cat final_recon.txt
```
📸 Screenshot: `03-final-recon.png`

**Note down:**
- Looking at this one command's output, list every distinct piece of information it gave you about the target (ports, services, versions, script results...).

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`. This also wraps up the full nmap arc (Days 04-07) — after this, Day 08 moves on to netcat.
