# 🧪 Lab Sheet — Networking Day 01: ping, traceroute & mtr

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

---

## Step 0: Check the tools are installed
```bash
which ping traceroute mtr
```
If `traceroute` or `mtr` is missing:
```bash
sudo apt update && sudo apt install -y traceroute mtr
```

---

## Part A: ping

```bash
# A1 - loopback (your own machine)
ping -c 4 127.0.0.1

# A2 - find your gateway
ip route | grep default

# A3 - ping your gateway (use the IP from A2)
ping -c 4 <gateway-ip>

# A4 - internet by IP
ping -c 4 8.8.8.8

# A5 - internet by name
ping -c 4 google.com

# A6 - deliberate failure (this address never replies)
ping -c 3 -W 1 192.0.2.1
```
📸 Screenshot: `01-ping-loopback-gateway.png` (A1 + A3), `02-ping-internet.png` (A4 + A5), `03-ping-fail.png` (A6)

**While running these, note down:**
- The `time=` value for loopback vs gateway vs 8.8.8.8 — how different are they?
- The `ttl=` value you see
- Did A4 (by IP) and A5 (by name) both succeed, or only one?

---

## Part B: traceroute

```bash
# B1
traceroute -n 8.8.8.8

# B2
traceroute google.com
```
📸 Screenshot: `04-traceroute.png`

**Note down:**
- How many hops did it take?
- Did any hop show `* * *`?

---

## Part C: mtr

```bash
# C1 - report mode, 10 packets, exits on its own
mtr -r -c 10 google.com
```
📸 Screenshot: `05-mtr-report.png`

**Note down:**
- Which hop had the highest latency?
- Did any hop show packet loss? If yes, was there also loss at the FINAL hop?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
