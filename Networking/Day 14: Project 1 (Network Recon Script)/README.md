# 🛠️ Networking Day 14: Project 1 (Network Report)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_14%2F15-blue?style=for-the-badge" alt="Day 14"/>
  <img src="https://img.shields.io/badge/project-network_report-orange?style=for-the-badge" alt="Project"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Days 01 to 13 each answered one question with one tool. A project day asks me to chain them into something repeatable: collect the facts about my own network and keep them as a report. 🛠️

---

## 🏆 Day 13 Recap — Challenge Solutions

**Challenge 1 (The Empty Export List):** The Text Filter box held a folder path. That box filters the object list by text, so every row was hidden. Clear it, select the response, click Save, and choose the folder in the Save dialog.

**Challenge 2 (Readable vs Protected):** Plain HTTP is decoded down to the headers and body. QUIC only shows addresses, ports, sizes, timing and a connection ID.

**Challenge 3 (Black and Red Rows):** `[TCP Retransmission]` on a SYN means no SYN-ACK came back, so the SYN was resent. It doesn't mean corruption, and a silent firewall drop (Day 04's "filtered") is one possible cause.

---

## 🎯 Mission Briefing

The plan for today was a script, `netrecon.sh`, that would sweep my lab subnet and summarise what it found. That script wasn't part of this run, so I built a smaller version by hand: first saving command outputs to report files, then wrapping five checks into one script that writes a report. Running `netrecon.sh` itself is still open.

```
🛠️  MISSION: Turn Commands Into a Report
──────────────────────────────────────────
[x] Save command output into report files (> and 2>&1)
[x] Read my own network layout: interfaces, gateway, subnet, DNS
[x] Check the loopback interface (details and ping)
[x] Wrap five checks into one report script
[ ] Make that script run cleanly: it overwrote itself the first time
[ ] netrecon.sh (ping sweep + nmap summary): not run yet
[ ] Part E improvement of netrecon.sh: not done
──────────────────────────────────────────
STATUS: Networking Day 14 — Partly done (3 items pending)
```

---

## ⚡ Quick Theory

**A report is just saved output.** `>` writes standard output into a file, `2>&1` sends error messages to the same place, and `tee` writes to a file while still printing to the screen. Wrapping several commands in `{ ...; }` lets one redirect or one `tee` catch all of them together.

**Know your own network first.** Recon of any network starts with the facts about where I'm standing: `ip -br -4 addr` (interfaces and addresses), `ip route` (gateway and subnets) and `/etc/resolv.conf` (which DNS server). The interface of the default route decides which subnet counts as "my" network.

**Loopback is special.** `lo` never touches a network card, so it has no real MAC address, a huge MTU and very fast round trips.

**A script file needs care.** It should start with a `#!` line (which interpreter runs it), and it must never write its output into its own file.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`. Everything here ran on my own machine. Long comment blocks trimmed with `...`)*

### 🗺️ Reading my network layout
```bash
$ ip -4 addr show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    inet 192.168.80.136/24 brd 192.168.80.255 scope global dynamic noprefixroute eth0
       valid_lft 1470sec preferred_lft 1470sec

$ ip route
default via 192.168.80.2 dev eth0 proto dhcp src 192.168.80.136 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
172.18.0.0/16 dev br-81243d49950f proto kernel scope link src 172.18.0.1
192.168.80.0/24 dev eth0 proto kernel scope link src 192.168.80.136 metric 100

$ cat /etc/resolv.conf
# This is /run/systemd/resolve/stub-resolv.conf managed by man:systemd-resolved(8).
...
nameserver 127.0.0.53
options edns0 trust-ad
search localdomain
```
What this tells me:

- `eth0`'s address is `dynamic` (`proto dhcp`), so it's leased. `valid_lft 1470sec` means about 24 minutes are left before it needs renewing.
- The default route points at `eth0` via `192.168.80.2`, so the subnet that belongs to my real network is `192.168.80.0/24`. The two Docker networks (`172.17.0.0/16`, which is `linkdown`, and `172.18.0.0/16`) are separate. This is the same table `netrecon.sh` reads to pick its target.
- `resolv.conf` points at `127.0.0.53`, the local systemd-resolved stub, which is the same server address `dig` reported on Day 02. On Day 12 Wireshark showed the same lookups leaving `eth0` for `192.168.80.2:53`. That fits: programs ask the local stub, and the stub forwards to the real DNS server (the gateway).

### 📄 Saving outputs as report files
```bash
$ mkdir -p ~/Desktop/network-lab/reports
$ cd ~/Desktop/network-lab/reports
$ ip -4 addr show > interface-report.txt
$ ip route > routing-report.txt
$ ping -c 4 127.0.0.1 > loopback-report.txt 2>&1

$ ls -lh ~/Desktop/network-lab/reports
total 12K
-rw-rw-r-- 1 ruin ruin 833 Oct 13 11:07 interface-report.txt
-rw-rw-r-- 1 ruin ruin 425 Oct 13 11:08 loopback-report.txt
-rw-rw-r-- 1 ruin ruin 305 Oct 13 11:08 routing-report.txt

$ cat loopback-report.txt
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.050 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.039 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.052 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.057 ms

--- 127.0.0.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3072ms
rtt min/avg/max/mdev = 0.039/0.049/0.057/0.006 ms
```
Three commands, three files, each readable on its own later. The `2>&1` on the ping sends any error text into the same file as the normal output.

### 🔁 The loopback interface
```bash
$ ip addr show lo
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute

$ ip link show lo
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

$ ping -c 4 127.0.0.1
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.044 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.083 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.046 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.047 ms

--- 127.0.0.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3076ms
rtt min/avg/max/mdev = 0.044/0.055/0.083/0.016 ms
```
`lo` has an all-zero MAC (`00:00:00:00:00:00`), an MTU of 65536 (`eth0`'s is 1500), and round trips of about 0.04 to 0.08 ms, roughly ten times quicker than the gateway's usual 0.2 to 0.8 ms. `state UNKNOWN` is normal for loopback.

### 🧾 A one-shot report script (and the bug)

Next I put five checks into one script that prints a report and saves it with `tee`. The code, saved in a file called `my-improvement.txt` (decorative lines shortened here):
```bash
{
    echo "══════════════════════════"
    echo "        MY NETWORKING IMPROVEMENT"
    echo "══════════════════════════"
    echo "Date: $(date)"
    echo ""
    echo "1. Network Interface"
    ip -br -4 addr
    echo ""
    echo "2. Default Gateway"
    ip route | grep default
    echo ""
    echo "3. Loopback Connectivity"
    ping -c 4 127.0.0.1
    echo ""
    echo "4. DNS Resolution"
    getent ahostsv4 example.com | head -3
    echo ""
    echo "5. Skills Practiced"
    echo "- IP and subnet identification"
    echo "- Gateway and routing checks"
    echo "- Ping and connectivity testing"
    echo "- DNS troubleshooting"
    echo "- Wireshark packet analysis"
    echo "- Saving command outputs as reports"
} 2>&1 | tee my-improvement.txt
```
Then I ran it:
```bash
$ chmod +x my-improvement.txt
$ ./my-improvement.txt
══════════════════════════
        MY NETWORKING IMPROVEMENT
══════════════════════════
Date: Tuesday 13 October 2026 11:12:19 AM IST

1. Network Interface
lo               UNKNOWN        127.0.0.1/8
eth0             UP             192.168.80.136/24
br-81243d49950f  UP             172.18.0.1/16
docker0          DOWN           172.17.0.1/16

2. Default Gateway
default via 192.168.80.2 dev eth0 proto dhcp src 192.168.80.136 metric 100

3. Loopback Connectivity
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.037 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.100 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.051 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.105 ms

--- 127.0.0.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3057ms
rtt min/avg/max/mdev = 0.037/0.073/0.105/0.029 ms

4. DNS Resolution
104.20.23.154   STREAM example.com
104.20.23.154   DGRAM
104.20.23.154   RAW

5. Skills Practiced
- IP and subnet identification
- Gateway and routing checks
- Ping and connectivity testing
- DNS troubleshooting
- Wireshark packet analysis
- Saving command outputs as reports
./my-improvement.txt: 27: .0.1: not found
./my-improvement.txt: 28: 4: not found
./my-improvement.txt: 29: rtt: not found
./my-improvement.txt: 31: 4.: not found
./my-improvement.txt: 32: 104.20.23.154: not found
./my-improvement.txt: 33: 104.20.23.154: not found
./my-improvement.txt: 34: 104.20.23.154: not found
./my-improvement.txt: 36: 5.: not found
./my-improvement.txt: 37: -: not found
...
./my-improvement.txt: 42: -: not found
```
The report itself came out correctly, and then a stream of `not found` errors followed. Each error quotes a fragment of the *report text* (`.0.1`, `rtt`, `104.20.23.154`, `5.`, `-`), and that's the clue. The shell was reading its own script, and the script had been replaced by the report. The last line, `tee my-improvement.txt`, opens the very file the shell is reading and empties it. The shell then carried on from where it had stopped, in a file that now held the report, and tried to run pieces of the report as commands. The file also has no `#!` line, so it was run by plain `sh`. The cost: the original code in `my-improvement.txt` was overwritten by the report.

One more detail in section 4: the same IP appears three times. `getent ahostsv4` prints each address once per socket type (`STREAM`, `DGRAM`, `RAW`), so `head -3` showed only the first address. `example.com` has two IPv4 addresses (`104.20.23.154` and `172.66.147.243`, seen on Days 12 and 13), and `head -3` hid the second.

---

## 🧪 What I Actually Found

- [x] Saved three command outputs as separate report files (interface 833 bytes, routing 305 bytes, loopback 425 bytes)
- [x] My network: `eth0` is `192.168.80.136/24` on a DHCP lease, the gateway is `192.168.80.2`, plus two Docker networks (`172.17.0.0/16` linkdown, `172.18.0.0/16`)
- [x] DNS: `resolv.conf` points at the local stub `127.0.0.53`, which forwards to the gateway
- [x] Loopback: MTU 65536, all-zero MAC, four pings between 0.037 and 0.105 ms, 0% loss
- [x] Built a five-section report script. It printed a correct report, then overwrote itself
- [ ] Re-run the report script correctly (separate output file, `#!` line, `.sh` name): fix understood, not re-run yet
- [ ] `netrecon.sh` (ping sweep + nmap summary): not run
- [ ] Part E improvement of `netrecon.sh` (`--top N`, run comparison or CSV inventory): not done

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Script That Ate Itself**
> My report printed fine, then a stream of `not found` errors followed, each quoting a piece of the report. What happened, and how do I fix it?

<details>
<summary>My answer</summary>

`tee my-improvement.txt` writes into the same file the shell was reading as its script. `tee` empties that file as soon as it starts, so the shell resumed reading in the middle of a file that now held the report, and tried to run fragments of the report text as commands (`.0.1`, `rtt`, `104.20.23.154`). The fix is to keep the script and its output in different files, and to give the script a real name and a `#!` line:
```bash
#!/bin/bash
{
    ... the same five sections ...
} 2>&1 | tee network-report-$(date +%F_%H-%M).txt
```
Save it as `network-report.sh`, then `chmod +x network-report.sh` and `./network-report.sh`. The dated report file can never collide with the script's own name.

</details>

> **🥊 Challenge 2: Three Lines, One Address**
> `getent ahostsv4 example.com | head -3` showed `104.20.23.154` three times. Is that three answers, and how do I list the real set of addresses?

<details>
<summary>My answer</summary>

No, it's one address printed three times. `getent ahostsv4` lists each address once per socket type (`STREAM`, `DGRAM`, `RAW`), so `head -3` only reached the first address and hid the second one (`172.66.147.243`). To list each address once:
```bash
getent ahostsv4 example.com | awk '{print $1}' | sort -u
```
`awk` keeps the first column and `sort -u` drops the repeats, the same text tools from the Linux journal.

</details>

> **🥊 Challenge 3: Loopback vs Ethernet**
> My loopback pings took about 0.04 to 0.1 ms while the gateway usually takes 0.2 to 0.8 ms, and `lo` has MTU 65536 against `eth0`'s 1500. What does this explain from Day 12's loopback capture?

<details>
<summary>My answer</summary>

Loopback traffic never reaches a network card or a wire. The kernel hands the packet straight back, which is why it's about ten times faster and has no real MAC (`00:00:00:00:00:00`, matching the all-zero Ethernet addresses in the Day 12 loopback capture). The MTU of 65536 explains why the `200 OK` in that capture was a single 14177-byte frame. On `eth0`, with an MTU of 1500, a frame that large couldn't exist and the page would be split into many smaller packets.

</details>

---

## 🧩 Quick Brain Check

1. What does `2>&1` do in `ping -c 4 127.0.0.1 > loopback-report.txt 2>&1`, and what would be missing from the file without it?
2. What does `tee` do, and why is it a problem when its target is the script's own file?
3. Why does a script file need a `#!` line?
4. What do `proto dhcp` and `valid_lft 1470sec` tell me about `eth0`'s address?
5. Why does the default route's interface decide which subnet a recon script should scan?

---

## 🐛 Errors / Gotchas I Hit

- The report script overwrote itself: `tee` wrote into the file the shell was reading. It also had no `#!` line and a `.txt` name, which made it easy to run the wrong way.
- `head -3` on `getent ahostsv4` hid the second address, because each address is printed three times.
- `netrecon.sh` wasn't run, so there's no ping sweep or nmap summary yet. Screenshots `01` to `03` contain commands I ran by hand, not `netrecon.sh` output.
- My "improvement" in Part E was a separate report script, not a change to `netrecon.sh`.

---

## 🔐 Security Relevance

Recon of any environment starts with knowing my own position: which interfaces exist, which subnet is mine, where the gateway and DNS server are. Timestamped report files are the evidence trail (what was run, when, and what it returned) that real assessments and asset inventories depend on. The bug is a security habit in miniature: read a script before making it executable, keep its output away from its own source, and remember that "private range" doesn't mean "my network". Scope is something I confirm myself, and no script can know it for me.

---

## 🧠 Today's Takeaway

A report is just saved output with a little structure: `>`, `2>&1` and `tee` do all the work. The network facts I need first (interfaces, gateway, subnet, DNS) are three commands away. And the most useful result of the day was the bug, because it showed how a shell reads a script: line by line, from a file that must not change underneath it.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 15: Project 2: capture lab traffic and write a short report**
