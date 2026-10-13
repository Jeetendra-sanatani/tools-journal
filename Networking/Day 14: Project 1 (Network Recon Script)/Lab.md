# 🧪 Lab Sheet — Networking Day 14: Project 1 (Network Recon Script)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

This is a project day. You get one script, `netrecon.sh`, that chains what Days 01 to 07 taught: a ping sweep (`-sn`, Day 04), a quick scan (`-F`, `-sV`, `-T4`, `--host-timeout`, Days 04 to 06), saved output (`-oA`, Day 07), and `awk` from the Linux journal to build a summary table. It's also the seed of an asset inventory: IP, hostname, MAC vendor and open services for every device on a network.

---

## ⚠️ Scope: read before you run anything

Run it **only on your own lab network.** Before running, check with `ip route`: the subnet should be the VMware NAT network you used on Day 04 (`192.168.80.0/24`). If your Kali VM is ever bridged onto the office network, or any network you don't own, don't run it.

The script has guards built in: private ranges only, `/24` or smaller, and you must retype the target to confirm. Those guards cannot know whether a private network is yours. That part is on you.

I tested the script's logic in my own environment, on a loopback target and on sample nmap files in the same formats nmap writes. I haven't seen your network, so your first real run is the real test. If anything breaks, send me the exact error text.

---

## Step 0: Read it before you run it

```bash
cd <folder where you saved netrecon.sh>
chmod +x netrecon.sh
bash -n netrecon.sh          # syntax check, runs nothing
less netrecon.sh             # read it. Never run a script you haven't read.
./netrecon.sh --help
```

---

## Part A: map the script to the days (no running yet)

Open `netrecon.sh` and, in `notes.txt`, match each function to the day and the command or flag it relies on.

```text
detect_target     ->  which Linux command finds the interface of the default route?
validate_target   ->  what three rules does it enforce, and why?
sweep             ->  which nmap flag does host discovery only? which day?
scan_hosts        ->  which flags keep a scan fast and stop it hanging on one host? (Days 04-05)
summarize         ->  which Linux text tools build the table? (Linux journal)
```

**Note down:**
- Which flag stops nmap from getting stuck on one slow host?
- Which output format (`.nmap`, `.gnmap`, `.xml`) does the script read to get hostnames and open ports, and which one does it read for MAC addresses?

---

## Part B: safe dry run on loopback

```bash
./netrecon.sh 127.0.0.1/32
# when asked, type:  127.0.0.1/32
```
📸 Screenshot: `01-loopback-run.png`

**Note down:**
- How many hosts were up, and which open ports did the summary list for your own machine?
- Compare with `ss -tuln`. Does the summary match what's actually listening? (The script only checks nmap's top 100 ports, so it may miss some.)
- Where were the reports saved?

---

## Part C: your own lab subnet

```bash
ip route
./netrecon.sh
# when asked, type the subnet it shows (e.g. 192.168.80.0/24)
```
📸 Screenshot: `02-lab-subnet-summary.png`

**Note down:**
- The summary table (IP, hostname, MAC, vendor, open ports).
- Which device is which: the gateway (`.2`), the VMware host adapter (`.1`), the helper at `.254`, and your own Kali machine?
- Compare with Day 04's `-sn` result (4 hosts up). Is anything new or missing?

---

## Part D: read the saved reports

```bash
LATEST=$(ls -dt ~/netrecon-reports/*/ | head -1)
ls -l "$LATEST"
cat "${LATEST}summary.txt"
head -30 "${LATEST}ports.nmap"
```
📸 Screenshot: `03-saved-reports.png`

**Note down:**
- How many files did one run create, and why that many? (Hint: two scans, three formats each, plus two more.)
- Which format would another tool parse most easily, and which is easiest to read yourself?

---

## Part E: make it yours (pick ONE)

- **E1:** add a `--top N` option so the number of ports scanned isn't fixed at `-F` (top 100).
- **E2:** compare this run's `live_hosts.txt` with the previous run and print which hosts are **new** and which are **missing**. (Hints: `ls -dt` gives newest first; `comm -13` and `comm -23` compare two sorted lists.)
- **E3:** also write an `inventory.csv` with the columns `ip,hostname,mac,vendor,ports`.

📸 Screenshot: `04-my-improvement.png` (the lines you changed plus a run showing it works)

**Note down:**
- Which one you picked, what you changed, and one thing that broke along the way.

---

## When you're done

Send me:
1. The screenshots (or the text of the summary table)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `notes.txt`, and write it up as a project.

**Reminder:** Day 11 (tcpdump filters) and the pending parts of Day 13 (Follow TCP Stream, Export Objects, DNS `MX`/NXDOMAIN, Statistics) are still waiting on real output.
