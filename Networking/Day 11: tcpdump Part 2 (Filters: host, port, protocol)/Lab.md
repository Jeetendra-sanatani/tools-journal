# 🧪 Lab Sheet — Networking Day 11: tcpdump Part 2 (Filters: host, port, protocol)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Only capture traffic on your own machine/interface (loopback `lo` and your own `eth0`).** Day 10 should be finished first, since this builds directly on it.

---

## Step 0: Set up a safe local web server (same trick you used for Wireshark)

Open **three terminals**:

```bash
# Terminal 1 - a tiny web server on your own machine, leave it running
mkdir -p ~/tcpdump-lab && cd ~/tcpdump-lab
echo "tcpdump filter practice" > index.html
python3 -m http.server 8080
```
```bash
# Terminal 2 - where you run tcpdump (commands below)
# Terminal 3 - where you generate traffic (curl / ping / dig, as each part says)
```

---

## Part A: filter by port and protocol

```bash
# A1 - only port 8080 traffic on loopback
sudo tcpdump -i lo -n port 8080 -c 10
#   Terminal 3 while it runs:   curl -s http://127.0.0.1:8080/ > /dev/null

# A2 - only TCP traffic on loopback
sudo tcpdump -i lo -n tcp -c 10
#   Terminal 3:                  curl -s http://127.0.0.1:8080/ > /dev/null

# A3 - only ICMP (ping) traffic on loopback
sudo tcpdump -i lo -n icmp -c 6
#   Terminal 3:                  ping -c 3 127.0.0.1
```
📸 Screenshot: `01-port-and-protocol.png`

**Note down:**
- In A1, can you see the TCP handshake flags (`[S]`, `[S.]`, `[.]`) and the HTTP request/response packets?
- In A3, why does each ping show up as TWO lines (request + reply)?

---

## Part B: filter by host and direction

```bash
# B1 - traffic to OR from a specific host
sudo tcpdump -i eth0 -n host 1.1.1.1 -c 8
#   Terminal 3:   ping -c 4 1.1.1.1

# B2 - only packets going TO that host (destination)
sudo tcpdump -i eth0 -n dst host 1.1.1.1 -c 4
#   Terminal 3:   ping -c 4 1.1.1.1

# B3 - only packets coming FROM that host (source)
sudo tcpdump -i eth0 -n src host 1.1.1.1 -c 4
#   Terminal 3:   ping -c 4 1.1.1.1
```
📸 Screenshot: `02-host-and-direction.png`

**Note down:**
- How many packets did B1 show compared to B2 and B3 for the same 4-ping test?
- Which of B2/B3 shows your machine's IP as the source, and which shows 1.1.1.1 as the source?

---

## Part C: combining filters with and / or / not

```bash
# C1 - AND: TCP traffic on port 8080, with readable payload
sudo tcpdump -i lo -n 'tcp and port 8080' -c 10 -A
#   Terminal 3:   curl -s http://127.0.0.1:8080/ > /dev/null

# C2 - NOT: everything on eth0 EXCEPT port 22 (classic "hide my own SSH session" filter)
sudo tcpdump -i eth0 -n 'not port 22' -c 10
#   Terminal 3:   ping -c 3 1.1.1.1

# C3 - OR: either ICMP or DNS
sudo tcpdump -i eth0 -n 'icmp or port 53' -c 8
#   Terminal 3:   ping -c 2 1.1.1.1    then    dig google.com
```
📸 Screenshot: `03-combined-filters.png`

**Note down:**
- In C1 with `-A`, could you read the `GET / HTTP/1.1` request and the `HTTP/1.0 200 OK` response as plain text?
- In C3, which packets matched `icmp` and which matched `port 53`?

---

## Part D: save with a filter, read it back

```bash
# D1 - capture ONLY the web server traffic into a file
sudo tcpdump -i lo -n port 8080 -c 12 -w http8080.pcap
#   Terminal 3:   curl -s http://127.0.0.1:8080/ > /dev/null

# D2 - read it back, then filter the saved file further
tcpdump -r http8080.pcap -n
tcpdump -r http8080.pcap -n 'tcp[tcpflags] & tcp-syn != 0'
ls -lh http8080.pcap
```
📸 Screenshot: `04-save-and-reread.png`

**Note down:**
- D2's second command shows only SYN packets — how many did you get, and what does that tell you about the number of connections made?
- Keep `http8080.pcap`. You can open it in Wireshark on Day 12.

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.

**Reminder:** Day 10's real tcpdump output is still pending. Send that first so the days get documented in order.
