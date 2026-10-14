# 🧪 Lab Sheet — Networking Day 15: Project 2 (Capture Your Lab Traffic, Write a Short Report)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

This is the last project of the networking series. You generate a small, known set of traffic on your own machine, capture it with the tools from Days 10 to 13, pull facts out of the capture, and write a one-page report. The report is the deliverable: every claim in it must trace back to a command or a screenshot.

**Only capture traffic on your own machine and your own lab network.** Today's traffic is: your own local web server, pings to your own gateway, and one DNS lookup.

I ran the capture, read-back and `tshark` commands below on a loopback test in my own environment, so the syntax is checked. I could not test the ping part (`icmp.resptime`) there, so if that one prints nothing, read the round-trip times in Wireshark instead.

---

## Step 0: Set up (3 terminals)

```bash
# Terminal 1 - a local web server, leave it running
mkdir -p ~/network-lab/day15 && cd ~/network-lab/day15
echo "day 15 report test" > index.html
python3 -m http.server 8080
```
```bash
# Terminals 2 and 3 - work in the same folder
cd ~/network-lab/day15
ip route          # note your gateway IP (the address after "default via")
```

---

## Part A: capture with tcpdump (this closes the Day 10 and Day 11 gaps)

**A1: web traffic on loopback**
```bash
# Terminal 2 - start the capture
sudo tcpdump -i lo -n 'tcp port 8080' -w web.pcap
```
```bash
# Terminal 3 - generate traffic (run this line 3 times, then go back to Terminal 2)
curl -s http://127.0.0.1:8080/ > /dev/null
```
Press **Ctrl+C** in Terminal 2. tcpdump prints how many packets it captured.

**A2: ping and DNS on eth0**
```bash
# Terminal 2
sudo tcpdump -i eth0 -n 'icmp or port 53' -w net.pcap
```
```bash
# Terminal 3 (use YOUR gateway IP from Step 0)
ping -c 4 192.168.80.2
dig example.com
```
Press **Ctrl+C** in Terminal 2.

```bash
ls -lh *.pcap
```
📸 Screenshot: `01-captures.png` (both tcpdump runs showing "packets captured", plus the `ls -lh` output)

**Note down:**
- Packet count and file size for `web.pcap` and for `net.pcap`.
- How many packets did 3 curl requests produce? (Compare with the 36 you saw on Day 12.)

---

## Part B: read the captures back with tcpdump

```bash
tcpdump -r web.pcap -n | head -20
tcpdump -r web.pcap -n 'tcp[tcpflags] & tcp-syn != 0'
tcpdump -r net.pcap -n
```
📸 Screenshot: `02-readback.png`

**Note down:**
- How many lines did the SYN filter print, and what does that number tell you about the curl requests? (Hint: SYN and SYN-ACK both carry the SYN flag.)
- Did tcpdump show the `GET / HTTP/1.1` request on its own, without `-A`?
- In `net.pcap`, which packets are ICMP and which are DNS, and which addresses talk to each other?

---

## Part C: pull out the facts (Wireshark or tshark)

Open `web.pcap` and `net.pcap` in Wireshark, or use `tshark`, which is Wireshark's command-line version:

```bash
# How many packets and how long? (capinfos is installed with Wireshark)
capinfos web.pcap | head -12

# How many TCP conversations?
tshark -r web.pcap -q -z conv,tcp

# Which client tool and which server software?
tshark -r web.pcap -Y http -T fields -e http.user_agent -e http.server

# How long did the server take to answer each request?
tshark -r web.pcap -Y http.response -T fields -e http.time

# What did DNS answer, and how fast?
tshark -r net.pcap -Y "dns.flags.response == 1" -T fields -e dns.qry.name -e dns.a -e dns.time

# Ping round-trip times (replies only)
tshark -r net.pcap -Y "icmp.type == 0" -T fields -e icmp.resptime
```
📸 Screenshot: `03-fact-extraction.png`

**Note down** (this becomes your fact sheet in `notes.txt`):
- Number of TCP conversations, packets per conversation, capture duration.
- Client tool and version, server software and version.
- Server response time for each of the 3 requests.
- The DNS answer(s) for `example.com` and the DNS response time.
- The 4 ping round-trip times.

---

## Part D: write the report

1. Copy `REPORT_TEMPLATE.md` to `report.md`.
2. Fill in every section **with your own numbers**.
3. Rules: every finding must name the command or screenshot that proves it, keep it to about one page, and the "Limits" section must list what you did NOT capture.

📸 Screenshot: `04-report.png` (the finished report, rendered or open in an editor)

**Note down:**
- Your one "surprise": something that didn't match what you expected.

---

## Part E: wrap up the networking series

1. Open `Networking/README.md` (the index) and update the status of any day you completed or fixed today.
2. In `notes.txt`, write your three-line reflection: the three tools you would reach for first on a real problem, the three things that surprised or tripped you up, and which pending item you'll close first.

📸 Screenshot: `05-index-updated.png` (the updated status table)

---

## When you're done

Send me:
1. The screenshots (or the text output of Parts A to C)
2. Your fact sheet and the finished `report.md`
3. Anything that errored or looked weird

I'll turn this into the final `README.md` for Day 15.

**Reminder:** the pending items listed in the `Networking/README.md` index are still open. Part A and Part B of today also close Day 10 (`-w`, `-r`) and the filter part of Day 11.
