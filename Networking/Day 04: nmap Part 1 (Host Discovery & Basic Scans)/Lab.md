# 🧪 Lab Sheet — Networking Day 04: nmap Part 1 (Host Discovery & Basic Scans)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

---

## ⚠️ Legal Reminder — Read This First

`nmap` is a scanning tool. Only scan:
- Your **own machine** (`127.0.0.1` / `localhost`)
- Your **own local network** (the one your Kali VM is actually connected to)
- **`scanme.nmap.org`** — the nmap project's own test server, which they explicitly allow the public to scan for learning

**Never scan an IP, domain, or network you don't own or don't have written permission for.** That includes office networks, even your own employer's, without IT's explicit sign-off.

---

## Step 0: Check nmap is installed
```bash
which nmap
nmap --version
```
nmap is pre-installed on Kali. If somehow missing: `sudo apt install -y nmap`

---

## Part A: host discovery on your own local network

```bash
# A1 - find your own network range first
ip route | grep -v default

# A2 - ping-scan your local subnet (replace with YOUR range from A1, e.g. 192.168.80.0/24)
# -sn = "no port scan, just find which hosts are up"
sudo nmap -sn 192.168.80.0/24
```
📸 Screenshot: `01-host-discovery.png`

**Note down:**
- How many hosts responded as "up" on your network?
- Do you recognize all of them (your router, your own machine, anything else)?

---

## Part B: scanning yourself (always safe)

```bash
# B1 - scan your own machine, default top 1000 ports
nmap localhost

# B2 - scan all 65535 ports on yourself (slower, but safe since it's your own machine)
nmap -p- localhost
```
📸 Screenshot: `02-scan-localhost.png` (B1 is enough if B2 takes too long — B2 is optional)

**Note down:**
- How many ports came back "open" on your own machine?
- What services are listed next to each open port?

---

## Part C: scanning scanme.nmap.org (explicitly permitted target)

```bash
# C1 - basic scan, default top 1000 ports
nmap scanme.nmap.org

# C2 - fast scan, top 100 ports only (quicker)
nmap -F scanme.nmap.org

# C3 - scan ONE specific port
nmap -p 22 scanme.nmap.org

# C4 - scan a specific RANGE of ports
nmap -p 1-100 scanme.nmap.org
```
📸 Screenshot: `03-scanme-basic.png` (C1), `04-scanme-fast-and-specific.png` (C2+C3+C4)

**Note down:**
- Which ports showed as open on scanme.nmap.org?
- Did the fast scan (-F) find the same open ports as the full scan, or fewer?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
