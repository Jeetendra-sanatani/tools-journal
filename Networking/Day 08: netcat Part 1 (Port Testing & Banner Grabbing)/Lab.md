# 🧪 Lab Sheet — Networking Day 08: netcat Part 1 (Port Testing & Banner Grabbing)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

---

## ⚠️ Scope for Today

- **Connecting OUT to test a port** (like checking if SSH/HTTP is open): fine against `scanme.nmap.org`, same rules as the nmap days.
- **Running a LISTENER** (`nc -lvnp <port>`): only ever on **your own machine** (`localhost`) or between **two of your own VMs on an isolated lab network**. Never run a listener reachable from the public internet, and never connect one of your listeners to anything you don't own.

---

## Step 0: Check netcat is installed
```bash
which nc
nc -h 2>&1 | head -5
```
Kali usually ships `ncat` (nmap's netcat) accessible as `nc`. If missing: `sudo apt install -y ncat` or `sudo apt install -y netcat-traditional`

---

## Part A: testing if a port is open (connect mode)

```bash
# A1 - test a known-open port
nc -zv scanme.nmap.org 22

# A2 - test a known-closed/filtered port
nc -zv scanme.nmap.org 443

# A3 - test a RANGE of ports at once
nc -zv scanme.nmap.org 20-30
```
📸 Screenshot: `01-port-testing.png`

**Note down:**
- What did `-zv` actually stand for? (hint: check `nc -h`)
- Did the range scan (A3) match what nmap found in Day 04-05 for similar ports?

---

## Part B: banner grabbing

```bash
# B1 - connect to SSH and see what it announces itself as (just the banner, then Ctrl+C)
nc -v scanme.nmap.org 22

# B2 - manually send an HTTP request and see the raw response
printf "GET / HTTP/1.1\r\nHost: scanme.nmap.org\r\nConnection: close\r\n\r\n" | nc -v scanme.nmap.org 80
```
📸 Screenshot: `02-banner-grabbing.png`

**Note down:**
- Did the SSH banner in B1 match the version nmap's `-sV` found on Day 06?
- In B2, what were the first few HTTP response headers you saw?

---

## Part C: a local listener (your own machine only)

```bash
# Terminal 1 - start a listener on your own machine
nc -lvnp 4444

# Terminal 2 - open a SECOND terminal, connect to yourself
nc -v 127.0.0.1 4444

# Now type a message in Terminal 2, press Enter - watch it appear in Terminal 1
# Type something back in Terminal 1, press Enter - watch it appear in Terminal 2
# Ctrl+C in both when done
```
📸 Screenshot: `03-local-listener.png`

**Note down:**
- What did this demonstrate about how netcat can be used for simple two-way communication?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
