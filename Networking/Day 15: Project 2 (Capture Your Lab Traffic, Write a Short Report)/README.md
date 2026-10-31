# 📋 Networking Day 15: Project 2 (Capture Your Lab Traffic, Write a Short Report)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_15%2F15-brightgreen?style=for-the-badge" alt="Day 15"/>
  <img src="https://img.shields.io/badge/project-capture_%2B_report-orange?style=for-the-badge" alt="Project"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The last day of the networking series. One capture, two tools reading it back, and a cross-check between what the capture says and what the live commands said at the time. 📋

---

## 🏆 Day 14 Recap — Challenge Solutions

**Challenge 1 (The Script That Ate Itself):** `tee` was writing into the same file the shell was reading as its script, so the script overwrote itself mid-run. Fix: separate the script from its output file, and give the script a `#!` line and a real name.

**Challenge 2 (Three Lines, One Address):** `getent ahostsv4` prints each address once per socket type, so `head -3` only reached the first address. `awk '{print $1}' | sort -u` lists each address once.

**Challenge 3 (Loopback vs Ethernet):** Loopback traffic never reaches a NIC, so it's faster and has no real MAC. Its 65536 MTU is why Day 12's 14177-byte response fit in a single frame; `eth0`'s 1500 MTU would have split it.

---

## 🎯 Mission Briefing

The plan was a capture of both web traffic (loopback) and ICMP/DNS traffic (eth0), read back two ways, turned into a fact sheet, then a one-page report. What actually got captured and analysed this round was the ICMP/DNS half: a `tcpdump` capture of a ping and a `dig` lookup, read back with filters, cross-checked against the live command output from the same moment. The web/HTTP capture and the narrative report are still open.

```
📋 MISSION: Capture, Read Back, Cross-Check
──────────────────────────────────────────
[x] Capture ICMP + DNS traffic with a filter (closes the Day 11 filter gap)
[x] Read the capture back with tcpdump -r (closes the Day 10 -w/-r gap)
[x] Cross-check packet timestamps against the live ping and dig output
[ ] Capture web traffic on loopback (web.pcap): not done
[ ] Fact extraction with tshark/capinfos: substituted with a tcpdump+wc script instead
[ ] report.md from the template: a report SCRIPT was written, not run or confirmed yet
[ ] Update the main Networking index: a separate local project readme was made instead
──────────────────────────────────────────
STATUS: Networking Day 15 — Partly done (4 items pending)
```

---

## ⚡ Quick Theory

**A capture filter narrows what gets saved, not just what's shown.** `tcp port 8080` or `icmp or port 53` passed to `tcpdump -w` means only matching packets ever reach the file. This is the fix for Day 10's problem, where an unfiltered `-c 10` capture filled up with background noise before any real traffic showed up.

**Two clocks measure the same event differently.** A tool like `ping` or `dig` times its own round trip: from the moment it hands a packet to the kernel, to the moment it gets the reply back, including its own setup and processing. `tcpdump`, watching the wire, times the gap between the packet actually leaving and the reply actually arriving. The two numbers are related but not identical, and comparing them is one way to tell how much of a "response time" is network versus local overhead.

**A ping's ICMP id ties a whole session together.** Every echo request and reply from one `ping` command shares the same `id`, so filtering or reading by that id (or just watching it stay constant) confirms which packets belong to which run, even in a capture with other traffic mixed in.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`. Capture: Terminal 1 ran `tcpdump`, Terminal 2 ran `ping` then `dig`, at the same time.)*

### 📡 Capturing with a filter
```bash
$ sudo tcpdump -i eth0 -n 'icmp or port 53' -w net.pcap
[sudo] password for ruin:
tcpdump: listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
^C10 packets captured
10 packets received by filter
0 packets dropped by kernel

$ ls -lh *.pcap
-rw-r--r-- 1 ruin ruin 1.2K Oct 14 14:25 net.pcap
```
10 packets, nothing dropped. That number is the first thing to check against the read-back.

### 🔁 Reading it back
```bash
$ tcpdump -nn -r net.pcap
reading from file net.pcap, link-type EN10MB (Ethernet), snapshot length 262144
14:24:04.098567 IP 192.168.80.136 > 192.168.80.2: ICMP echo request, id 31126, seq 1, length 64
14:24:04.099136 IP 192.168.80.2 > 192.168.80.136: ICMP echo reply, id 31126, seq 1, length 64
14:24:05.128035 IP 192.168.80.136 > 192.168.80.2: ICMP echo request, id 31126, seq 2, length 64
14:24:05.128647 IP 192.168.80.2 > 192.168.80.136: ICMP echo reply, id 31126, seq 2, length 64
14:24:06.129378 IP 192.168.80.136 > 192.168.80.2: ICMP echo request, id 31126, seq 3, length 64
14:24:06.129725 IP 192.168.80.2 > 192.168.80.136: ICMP echo reply, id 31126, seq 3, length 64
14:24:07.143942 IP 192.168.80.136 > 192.168.80.2: ICMP echo request, id 31126, seq 4, length 64
14:24:07.144737 IP 192.168.80.2 > 192.168.80.136: ICMP echo reply, id 31126, seq 4, length 64
14:24:07.317679 IP 192.168.80.136.58618 > 192.168.80.2.53: 1260+ [1au] A? example.com. (40)
14:24:07.327862 IP 192.168.80.2.53 > 192.168.80.136.58618: 1260 2/0/1 A 172.66.147.243, A 104.20.23.154 (72)
```
10 lines, matching the "10 packets captured" tcpdump reported live: 4 request/reply pairs (8 packets) plus one DNS query and its response (2 packets). Every ICMP line carries the same `id 31126`, confirming all 4 pairs belong to one `ping` run.

### 🧮 A fact-extraction script (tcpdump + wc, instead of tshark)
```bash
$ {
  echo "═══ PCAP FACT EXTRACTION ═══"
  date
  echo ""
  echo "1. Total Packets"
  sudo tcpdump -nn -r net.pcap 2>/dev/null | wc -l
  echo ""
  echo "2. ICMP Traffic"
  sudo tcpdump -nn -r net.pcap icmp
  echo ""
  echo "3. DNS Traffic"
  sudo tcpdump -nn -r net.pcap port 53
} | tee ~/Desktop/network-lab/reports/fact-extraction.txt
═══ PCAP FACT EXTRACTION ═══
Wednesday 14 October 2026 02:38:15 PM IST

1. Total Packets
10

2. ICMP Traffic
reading from file net.pcap, link-type EN10MB (Ethernet), snapshot length 262144
... (the same 8 ICMP lines as above)

3. DNS Traffic
reading from file net.pcap, link-type EN10MB (Ethernet), snapshot length 262144
... (the same 2 DNS lines as above)
```
Instead of `tshark -T fields`, this pulls facts by re-reading the same file with a different filter each time (`icmp`, then `port 53`) and piping the total through `wc -l`. It reaches the same answer the lab sheet's `tshark`/`capinfos` commands were aimed at, just with a tool already covered on Days 10 and 11. `wc -l` only works here because `tcpdump` prints exactly one line per packet with no `-v`; a more verbose mode would have broken that count.

### 🖊️ Building a report script (not yet run)
```bash
$ cat ~/Desktop/network-lab/reports/report.txt
{
  echo "═══════════"
  echo "   PCAP ANALYSIS REPORT"
  echo "═══════════"
  echo "Date: $(date)"
  echo "Capture File: $HOME/net.pcap"
  echo ""
  echo "1. CAPTURE FILE DETAILS"
  ls -lh "$HOME/net.pcap"
  echo ""
  echo "2. TOTAL PACKETS"
  sudo tcpdump -nn -r "$HOME/net.pcap" 2>/dev/null | wc -l
  echo ""
  echo "3. ICMP TRAFFIC"
  sudo tcpdump -nn -r "$HOME/net.pcap" icmp 2>/dev/null
  echo ""
  echo "4. DNS TRAFFIC"
  sudo tcpdump -nn -r "$HOME/net.pcap" port 53 2>/dev/null
  echo ""
  echo "═══════════"
  echo "   END OF REPORT"
  echo "═══════════"
} | tee ~/Desktop/network-lab/reports/final-report.txt

$ ls -lh ~/Desktop/network-lab/reports/report.txt
-rw-rw-r-- 1 ruin ruin 740 Oct 14 14:41 /home/ruin/Desktop/network-lab/reports/report.txt
```
This is the script's source, saved as `report.txt`, written to produce `final-report.txt` when run. One thing worth catching before running it: it reads `$HOME/net.pcap`, but the capture above was saved in the current directory, not `$HOME` directly - worth confirming the path matches before trusting the output. The script hasn't been run yet, so `final-report.txt` doesn't exist and this isn't confirmed working end to end.

### 📝 A project summary (instead of updating the series index)
```bash
$ cat ~/Desktop/network-lab/readme.md
# Network Traffic Analysis Lab

## Objective
Practice packet capture, PCAP readback, fact extraction, and report creation using tcpdump.

## Practical Index

| No. | Practical | Evidence |
|-----|-----------|----------|
| 01 | Capture ICMP and DNS traffic | 01-captures.png |
| 02 | Read saved PCAP file | 02-readback.png |
| 03 | Extract network facts | 03-fact-extraction.png |
| 04 | Generate final analysis report | 04-report.png |
| 05 | Update practical index | 05-index-updated.png |

## Files
- `~/net.pcap` - saved packet capture
- `reports/fact-extraction.txt` - extracted packet facts
- `reports/final-report.txt` - final analysis report

## Tools Used
- tcpdump
- ping
- dig
- Linux shell commands

## Learning Outcome
Captured network traffic, reviewed saved packets, extracted ICMP/DNS information, and documented findings.
```
This documents the lab itself, rather than updating the status table in `Networking/README.md` as the lab sheet asked. It's a reasonable thing to have either way, but the series index is still showing its old status.

---

## 🔬 Cross-Checking the Capture Against the Live Output

The `ping` and `dig` commands that generated this traffic were run at the same time as the capture, in a separate terminal:
```bash
$ ping -c 4 192.168.80.2
64 bytes from 192.168.80.2: icmp_seq=1 ttl=128 time=0.709 ms
64 bytes from 192.168.80.2: icmp_seq=2 ttl=128 time=0.680 ms
64 bytes from 192.168.80.2: icmp_seq=3 ttl=128 time=0.391 ms
64 bytes from 192.168.80.2: icmp_seq=4 ttl=128 time=0.865 ms
--- 192.168.80.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3045ms
rtt min/avg/max/mdev = 0.391/0.661/0.865/0.171 ms

$ dig example.com
;; ANSWER SECTION:
example.com.      5      IN      A       172.66.147.243
example.com.      5      IN      A       104.20.23.154
;; Query time: 23 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Wed Oct 14 14:24:07 IST 2026
```
`dig`'s timestamp (`14:24:07`) and the two addresses it returned match the DNS packets in `net.pcap` exactly, so this is the same lookup, seen from two angles. Two comparisons worth pulling out:

**ICMP round trips.** Subtracting the capture's own request/reply timestamps gives 0.569, 0.612, 0.347 and 0.795 ms for the four pings, each a bit lower than what `ping` itself reported (0.709, 0.680, 0.391, 0.865 ms). `ping` measures from handing the packet to the kernel to receiving the reply back in its own process, while `tcpdump`'s timestamps are taken closer to the wire; the small, consistent gap between the two (roughly 0.07 to 0.14 ms each time) fits that difference, though I haven't confirmed this is the whole explanation.

**DNS query time.** The capture shows the query at `14:24:07.317679` and the response at `14:24:07.327862`, a gap of about 10.2 ms. `dig` itself reported `Query time: 23 msec`, roughly double. The two numbers are measuring different things (dig's own request-to-answer timer versus the wire-to-wire gap in the capture), but a factor-of-two difference is larger than the ICMP gap and I don't have a confirmed explanation for it yet.

---

## 🧪 What I Actually Found

- [x] `net.pcap`: 10 packets captured, 1.2K, 0 dropped
- [x] Read-back matches exactly: 8 ICMP packets (4 request/reply pairs, same `id 31126`) + 2 DNS packets
- [x] `dig`'s answer and timestamp line up exactly with the DNS packets in the capture, confirming it's the same lookup
- [x] ICMP round trips from the capture (0.35-0.80 ms) run a little under `ping`'s own reported times (0.39-0.87 ms), a gap consistent with where each tool takes its timestamp
- [x] DNS: capture shows a ~10.2 ms gap between query and response; `dig` reported 23 ms - not yet explained
- [ ] Web traffic capture (`web.pcap`, 3 curl requests on loopback): not done
- [ ] `tshark`/`capinfos` fact extraction: substituted with a `tcpdump`-based script instead
- [ ] `report.md` narrative from `REPORT_TEMPLATE.md`: a shell script was written instead, and it hasn't been run yet
- [ ] `Networking/README.md` index update: a separate local project readme was written instead

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Ten Packets, Two Tools, One Count**
> The live `tcpdump` run said "10 packets captured", and the fact-extraction script's `wc -l` on the same file also said 10. Does matching twice prove the capture is complete and correct?

<details>
<summary>My answer</summary>

It's good evidence, but not proof by itself. `wc -l` only equals the packet count because `tcpdump -r` without `-v` prints exactly one line per packet; a more detailed mode would break that. What actually confirms it is the third check: reading the file with `icmp` gives 8 lines and with `port 53` gives 2, and 8 + 2 = 10. Three independent counts agreeing is stronger evidence than any one of them alone.

</details>

> **🥊 Challenge 2: Two Numbers for One Round Trip**
> The capture's own timestamps give shorter ICMP round trips than `ping` reported, every single time. Does that mean the capture is wrong?

<details>
<summary>My answer</summary>

No, they're measuring different boundaries of the same event. `ping` times from when it hands the packet to the kernel to when it gets the reply back in its own process, which includes some userspace and kernel overhead on both ends. `tcpdump` times from when the packet is seen crossing the capture point to when the reply is seen, which is closer to the actual wire time. A small, consistent gap between the two, as seen here, is expected rather than an error.

</details>

> **🥊 Challenge 3: A Gap That Doesn't Add Up**
> The DNS query-to-response gap in the capture was about 10 ms, but `dig` reported a 23 ms query time, roughly double. What's a reasonable way to actually find out why, rather than guessing?

<details>
<summary>My answer</summary>

Run the same lookup a few more times and see whether the ratio holds, since one sample could be a coincidence. Capture with `tcpdump -tt` or open the file in Wireshark and check the DNS response's `[Time: ...]` field directly rather than subtracting timestamps by hand, which removes any arithmetic error. And compare `dig`'s timer against a lookup where the answer is cached versus not, since `dig` might be including local resolver work that happens before anything reaches the wire. I haven't done any of this yet, so the 23 ms vs 10 ms gap stays an open question rather than a conclusion.

</details>

---

## 🧩 Quick Brain Check

1. Why does reading `net.pcap` with the `icmp` filter and then with the `port 53` filter, and adding the two counts, confirm something that just reading the whole file once doesn't?
2. Why might `ping`'s reported round-trip time differ slightly from the gap between request and reply timestamps in a capture of the same traffic?
3. What does it mean that every ICMP packet in this capture shares `id 31126`?
4. Why is a script that reads `$HOME/net.pcap` risky to run without checking the path first, if the capture was actually saved in the current directory?
5. Why does a report that names its evidence (a specific command or screenshot) carry more weight than one that just states a number?

---

## 🐛 Errors / Gotchas I Hit

- The planned `web.pcap` loopback capture (3 curl requests) wasn't taken this round; everything captured and analysed was the ICMP/DNS side.
- The report script (`report.txt`) was written to read `$HOME/net.pcap`, but the capture shown was made in the working directory, not confirmed to be `$HOME`. Worth checking the path before trusting a run.
- `report.txt` holds the script's source; it hasn't actually been run, so `final-report.txt` doesn't exist yet and the script isn't confirmed to work end to end.
- The DNS query-to-response gap measured from the capture (about 10 ms) doesn't match `dig`'s own reported query time (23 ms), and I don't have a confirmed reason why yet.
- `fact-extraction.txt` was listed at 39 bytes in one `ls`, which is too small to hold the ICMP + DNS output shown being written to that same file - the file was likely rewritten after that listing was taken, but there's no later `ls` confirming its final size.

---

## 🔐 Security Relevance

Cross-checking a capture against the live tool output is the same discipline a real investigation needs: a single number from one source is a claim, and the same number confirmed from an independent source (the wire, not just the tool's own report) is evidence. The gap between `ping`'s self-reported time and the wire time is a reminder that any single tool's timing can include work that never touched the network at all, which matters when timing is being used to prove something happened on the wire specifically, like in a timing-based investigation.

---

## 🧠 Today's Takeaway

A live packet count and a read-back packet count agreeing is a basic but real check, and splitting that count by protocol (ICMP, then DNS) and adding the pieces back up is a stronger one. Two tools measuring "the same" round trip rarely give identical numbers, because they're timing different boundaries, and a difference worth investigating (like the DNS gap here) is more valuable left open than explained away without checking. That closes the 15-day networking series: ping and traceroute (Day 01) through nmap, netcat, tcpdump, Wireshark, and two projects that turned captured packets into a written record.

---

⬅️ [Back to Networking index](/Networking)
