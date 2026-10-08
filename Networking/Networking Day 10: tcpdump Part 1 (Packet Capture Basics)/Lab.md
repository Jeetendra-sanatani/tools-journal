# 🧪 Lab Sheet — Networking Day 10: tcpdump Part 1 (Packet Capture Basics)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Only capture traffic on your own machine/interface. Capturing traffic on a network you don't control or own is not something to do, even out of curiosity.**

---

## Step 0: Check tcpdump is installed, find your interface
```bash
which tcpdump
ip addr                    # find your interface name, e.g. eth0
sudo tcpdump --list-interfaces
```
tcpdump is pre-installed on Kali. If missing: `sudo apt install -y tcpdump`

---

## Part A: a basic live capture

```bash
# A1 - capture on your main interface, limited to 10 packets, then stop automatically
sudo tcpdump -i eth0 -c 10

# A2 - same, but don't resolve hostnames/ports to names (raw numbers, faster, often clearer)
sudo tcpdump -i eth0 -c 10 -n
```
While this is running, generate some traffic in ANOTHER terminal (e.g. `ping -c 4 1.1.1.1` or `curl -s https://example.com > /dev/null`) so there's something to actually capture.

📸 Screenshot: `01-basic-capture.png`

**Note down:**
- What does one line of tcpdump's output actually show (source, destination, flags)?
- How did the output change between A1 (with name resolution) and A2 (-n, numeric only)?

---

## Part B: capturing a specific kind of traffic

```bash
# B1 - capture ONLY on a specific interface, with packet contents shown
sudo tcpdump -i eth0 -c 5 -A

# B2 - increase verbosity (more detail per packet)
sudo tcpdump -i eth0 -c 5 -v
```
Generate some traffic again while these run (a `curl` to an http:// site works well for `-A`, since you'll see readable text).

📸 Screenshot: `02-verbose-and-ascii.png`

**Note down:**
- With `-A`, could you actually read any plain-text content in the capture (like an HTTP request)?
- What extra fields appeared with `-v` that weren't in the basic A1/A2 output?

---

## Part C: saving a capture to a file

```bash
# C1 - save raw packet data to a .pcap file instead of printing to screen
sudo tcpdump -i eth0 -c 20 -w capture.pcap

# C2 - read back what you just saved
tcpdump -r capture.pcap

# C3 - check the file itself
ls -lh capture.pcap
file capture.pcap
```
📸 Screenshot: `03-saving-pcap.png`

**Note down:**
- Does the saved-and-reread output (C2) look the same as live output would?
- What does the `file` command say about what KIND of file a `.pcap` actually is?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
