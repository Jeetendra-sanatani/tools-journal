# 📡 Networking Day 10: tcpdump Part 1 (Packet Capture Basics)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_10%2F15-blue?style=for-the-badge" alt="Day 10"/>
  <img src="https://img.shields.io/badge/tool-tcpdump-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Days 04-09 worked with ports, services and connections. tcpdump goes one level lower: it shows the actual packets crossing the wire, including the ones I never asked for. 📡

---

## 🏆 Day 09 Recap — Challenge Solutions

**Challenge 1 (No Automatic Stop):** A raw netcat transfer has no explicit end-of-file signal, so the listener can't tell "done" from "paused". For big files that means no completion confirmation and no resume, so size and checksum have to be checked separately.

**Challenge 2 (Verifying, Not Assuming):** Size alone or content alone can miss problems. Checking both (and a real checksum for anything important) gives real confidence.

**Challenge 3 (Same Tool, Different Job):** Only the redirection around netcat changed (`> file` and `< file`), not netcat itself.

---

## 🎯 Mission Briefing

Until now every tool reported a *result*: open or closed, up or down, a version string. tcpdump shows the raw conversation itself, every packet in order with a timestamp. Today: find the right interface, capture a small batch, read what's in it, and read back a saved capture file.

```
📡 MISSION: See the Packets
──────────────────────────────────────────
[x] Find my network interfaces with ip addr
[x] Capture a small batch of live packets on eth0
[x] Read ARP, DNS and TCP lines in raw tcpdump output
[x] Read back a saved capture file with -r
[ ] -A / -v / -w: still to do (see What I Actually Found)
──────────────────────────────────────────
STATUS: Networking Day 10 — Done (3 items still pending)
```

---

## ⚡ Quick Theory

**tcpdump** captures packets as they pass through a network interface and prints one line per packet. Capturing needs root (`sudo`) because it exposes everything crossing that interface. Reading a saved file with `-r` doesn't need it.

**Pick the right interface.** A machine often has more than `eth0`: loopback (`lo`) for traffic to itself, plus any virtual interfaces (Docker bridges, veth pairs, VPN tunnels). `ip addr` lists them, and `-i <name>` chooses which one tcpdump listens on.

**Reading one line:**
```text
10:25:29.685566 IP 192.168.80.136.57366 > 192.168.80.2.5355: Flags [S], seq 3413592564, win 64240, length 0
```
- `10:25:29.685566` is the timestamp
- `IP` is the protocol layer
- `192.168.80.136.57366 > 192.168.80.2.5355` is source IP.port going to destination IP.port (the number after the last dot is the port)
- `Flags [S]` are the TCP flags
- `length 0` is the payload size in bytes (0 means a pure control packet, no data)

**TCP flags you'll see constantly** (the dot means ACK is set):
```text
[S]    SYN       start a connection
[S.]   SYN-ACK   connection accepted
[.]    ACK       acknowledgement
[P.]   PSH-ACK   data being sent (e.g. an HTTP request or response)
[F.]   FIN-ACK   connection closing
[R.]   RST-ACK   connection refused / reset
```

**Name resolution is on by default, and `-n` turns it off.** Without `-n`, tcpdump tries to turn IPs into hostnames and port numbers into service names (`127.0.0.1` becomes `localhost`, `8080` becomes `http-alt`). That reads nicely, but it can trigger extra DNS lookups, which then show up in the capture and muddy it. `-n` keeps everything numeric, faster and cleaner for analysis.

**Capture file formats:** `tcpdump -w` writes the classic `.pcap` format, while Wireshark saves the newer `.pcapng`. tcpdump can read both with `-r`, and `file` tells you which one you have.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`. Long option lists trimmed with `...`)*

### 🗺️ Finding my interfaces
```bash
$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ... state UP
    link/ether 00:0c:29:d0:b1:af
    inet 192.168.80.136/24 brd 192.168.80.255 scope global dynamic noprefixroute eth0
3: br-81243d49950f: <BROADCAST,MULTICAST,UP,LOWER_UP> ... state UP
    inet 172.18.0.1/16 brd 172.18.255.255 scope global br-81243d49950f
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> ... state DOWN
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
5: veth5cdc1b8@if2: ... master br-81243d49950f state UP
6: vethd980431@if2: ... master br-81243d49950f state UP
7: veth56428c5@if2: ... master br-81243d49950f state UP
```
My real network is `eth0` (`192.168.80.136/24`, MAC `00:0c:29:d0:b1:af`). It isn't the only interface though: Docker added its own bridge (`br-81243d49950f`), the default `docker0` bridge (currently DOWN, no carrier), and three `veth` interfaces plugged into that bridge (the host-side ends of virtual cables to containers). That's why choosing the interface explicitly with `-i eth0` matters.

### 📡 A live capture on eth0
```bash
$ sudo tcpdump -i eth0 -c 10 -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
10:25:29.493746 ARP, Request who-has 192.168.80.2 tell 192.168.80.1, length 46
10:25:29.544783 IP 192.168.80.136.51957 > 192.168.80.2.53: 57401+ [1au] PTR? 2.80.168.192.in-addr.arpa. (54)
10:25:29.554403 ARP, Request who-has 192.168.80.136 tell 192.168.80.2, length 46
10:25:29.554424 ARP, Reply 192.168.80.136 is-at 00:0c:29:d0:b1:af, length 28
10:25:29.555072 IP 192.168.80.2.53 > 192.168.80.136.51957: 57401 NXDomain 0/0/1 (54)
10:25:29.685566 IP 192.168.80.136.57366 > 192.168.80.2.5355: Flags [S], seq 3413592564, win 64240, options [mss 1460,sackOK,TS val 1685199771 ecr 0,nop,wscale 10,tfo cookiereq,nop,nop], length 0
10:25:29.685979 IP 192.168.80.2.5355 > 192.168.80.136.57366: Flags [R.], seq 0, ack 3413592565, win 32767, length 0
10:25:29.687039 IP 192.168.80.136.59884 > 192.168.80.2.53: 31877+ [1au] PTR? 1.80.168.192.in-addr.arpa. (54)
10:25:29.935715 IP 192.168.80.136.57558 > 192.168.80.1.5355: Flags [S], seq 2146231900, win 64240, options [mss 1460,sackOK,TS val 3009118978 ecr 0,nop,wscale 10,tfo cookiereq,nop,nop], length 0
10:25:29.936447 IP 192.168.80.1.5355 > 192.168.80.136.57558: Flags [R.], seq 0, ack 2146231901, win 0, length 0
10 packets captured
10 packets received by filter
0 packets dropped by kernel
```
None of these ten packets is a ping or a curl of mine, so my test traffic never made it into this capture. What it caught instead was background traffic, in three kinds:

- **ARP (lines 1, 3, 4):** devices on the local network asking "who has this IP?" so they can find its MAC address. Line 4 is my own machine answering: `192.168.80.136 is-at 00:0c:29:d0:b1:af`, the exact MAC that `ip addr` showed for `eth0`.
- **DNS reverse lookups (lines 2, 5, 8):** my machine asked the DNS server at `192.168.80.2:53` for `PTR?` records, meaning "what name belongs to this IP?" (the same idea as `dig -x` on Networking Day 02). The answer `NXDomain` means no such name exists.
- **TCP SYN followed by RST on port 5355 (lines 6-7 and 9-10):** my machine sent a connection request (`[S]`) to port 5355 on `192.168.80.2` and on `192.168.80.1`, and both answered with a reset (`[R.]`). This is the packet-level version of "Connection refused" from Networking Day 08: the host is there, nothing is listening on that port. Port 5355 is the standard port for LLMNR (local name resolution). I haven't traced which process produced the DNS lookups or the port 5355 attempts.

### 📖 Reading back a saved capture
```bash
$ cd ~/Desktop/wireshark_practice
$ tcpdump -r basic_capture.pcapng
reading from file basic_capture.pcapng, link-type EN10MB (Ethernet), snapshot length 262144
10:07:42.344605 IP localhost.55132 > localhost.http-alt: Flags [S], seq 3106649730, win 65495, ..., length 0
10:07:42.344619 IP localhost.http-alt > localhost.55132: Flags [S.], seq 3968931951, ack 3106649731, win 65483, ..., length 0
10:07:42.344630 IP localhost.55132 > localhost.http-alt: Flags [.], ack 1, win 64, ..., length 0
10:07:42.344696 IP localhost.55132 > localhost.http-alt: Flags [P.], seq 1:79, ack 1, win 64, ..., length 78: HTTP: GET / HTTP/1.1
10:07:42.344701 IP localhost.http-alt > localhost.55132: Flags [.], ack 79, win 64, ..., length 0
10:07:42.345393 IP localhost.http-alt > localhost.55132: Flags [P.], seq 1:189, ack 79, win 64, ..., length 188: HTTP: HTTP/1.0 200 OK
10:07:42.345421 IP localhost.55132 > localhost.http-alt: Flags [.], ack 189, win 64, ..., length 0
10:07:42.345470 IP localhost.http-alt > localhost.55132: Flags [P.], seq 189:14300, ack 79, win 64, ..., length 14111: HTTP
10:07:42.345497 IP localhost.55132 > localhost.http-alt: Flags [.], ack 14300, win 106, ..., length 0
10:07:42.345540 IP localhost.http-alt > localhost.55132: Flags [F.], seq 14300, ack 79, win 64, ..., length 0
10:07:42.345892 IP localhost.55132 > localhost.http-alt: Flags [F.], seq 79, ack 14301, win 106, ..., length 0
10:07:42.345907 IP localhost.http-alt > localhost.55132: Flags [.], ack 80, win 64, ..., length 0
... (two more identical conversations, from source ports 55148 and 55150)

$ file basic_capture.pcapng
basic_capture.pcapng: pcapng capture file - version 1.0
```
This is the capture I made earlier in Wireshark of three `curl` requests to my local `python3 -m http.server 8080`. tcpdump reads Wireshark's file without trouble and shows the same three connections (source ports 55132, 55148, 55150), 12 packets each, 36 in total. Each conversation is the whole life of one HTTP request:

- `[S]`, `[S.]`, `[.]`: the three-way handshake
- `[P.]` with `GET / HTTP/1.1` (78 bytes): the request
- `[P.]` with `HTTP/1.0 200 OK` (188 bytes of headers), then `[P.]` with 14111 bytes: the page itself
- `[F.]`, `[F.]`, `[.]`: the connection closing

Compare the addresses here (`localhost.http-alt`) with the live capture (`192.168.80.2.5355`). Same format, but this read didn't use `-n`, so tcpdump swapped `127.0.0.1` for `localhost` and `8080` for `http-alt`.

---

## 🧪 What I Actually Found

- [x] `eth0` is `192.168.80.136/24`, and Docker added a bridge, `docker0` and three `veth` interfaces on top of that
- [x] 10-packet live capture on eth0 with `-n`: ARP, DNS PTR with NXDomain, TCP SYN answered by RST on port 5355
- [x] My machine's ARP reply matched the MAC address shown by `ip addr`
- [x] None of the 10 packets was my own test traffic, only background traffic
- [x] `tcpdump -r` read a Wireshark-made `.pcapng`: 3 HTTP conversations x 12 packets = 36 packets, from handshake to GET to 200 OK to FIN
- [x] `file` identified it as `pcapng capture file - version 1.0`
- [ ] `-A` (ASCII payload) and `-v` (verbose): not captured this round
- [ ] `-w` (writing my own `.pcap` with tcpdump): not done this round, the file I read back was made by Wireshark

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Ten Strangers**
> None of the 10 packets was a ping or a curl. Why can an interface capture traffic I never started, and why does that matter when capturing with `-c 10`?

<details>
<summary>My answer</summary>

A network is never silent: ARP, DNS lookups and name-resolution attempts happen all the time. `-c 10` stops after the first 10 packets, whatever they are, so if my test traffic doesn't happen while the capture is running (or background chatter fills the quota first), the capture contains noise instead of what I wanted. This is the problem filters (Day 11) solve: capture only the traffic I care about.

</details>

> **🥊 Challenge 2: Refused at the Packet Level**
> Two SYN packets to port 5355 got `[R.]` back. What does that tell me, and how does it connect to Networking Day 08?

<details>
<summary>My answer</summary>

A reset means the target host is reachable and answered immediately, but nothing is listening on that port. It's the same thing as "Connection refused" in netcat on Day 08, now seen as raw packets. A filtered port (Day 04) would have produced no reply at all instead of a reset.

</details>

> **🥊 Challenge 3: Names vs Numbers**
> The live capture shows `192.168.80.2.5355`, but the saved-file read shows `localhost.http-alt`. What accounts for the difference, and why is `-n` usually the better choice for analysis?

<details>
<summary>My answer</summary>

The live capture used `-n` (numeric only). The `-r` read didn't, so tcpdump translated `127.0.0.1` to `localhost` and `8080` to `http-alt`. `-n` is usually better because the output is exact, it's faster, and it doesn't trigger extra DNS lookups that would themselves appear in the capture as noise.

</details>

---

## 🧩 Quick Brain Check

1. Why does tcpdump need `sudo` to capture, but not to read a saved file with `-r`?
2. What does `[S.]` mean, and which side of a connection sends it?
3. What's the difference between an ARP request and an ARP reply? What is each one asking or answering?
4. How can you tell from tcpdump output that a port is closed rather than filtered?
5. What do `-c 10` and `-n` each change about how a capture behaves?

---

## 🐛 Errors / Gotchas I Hit

- The interface list had more than `lo` and `eth0`: Docker's bridge, `docker0` and `veth` interfaces too. Picking the interface explicitly (`-i eth0`) isn't optional, since guessing wrong captures nothing useful.
- With `-c 10`, the capture stopped after the first 10 packets and all 10 were background traffic (ARP, DNS PTR, port 5355), so my own test traffic never made it in. Next time: start generating traffic as soon as the capture starts, and use a filter (Day 11) so only relevant packets count toward the 10.
- This round I read back a `.pcapng` made by Wireshark instead of writing a `.pcap` with `tcpdump -w`, and I didn't capture `-A` or `-v`. These are still open items.

---

## 🔐 Security Relevance

A capture shows what's really on the wire: here, ordinary background traffic (ARP, reverse DNS, a refused connection) from a machine that wasn't doing anything dramatic. Plain HTTP is fully readable in a capture. The `GET / HTTP/1.1` request and the `200 OK` response were visible without any decryption, which is exactly why unencrypted protocols are a risk on a shared network and why HTTPS matters. Defenders use captures like this to spot unexpected connections; attackers and pentesters use them to look for credentials or data moving in cleartext. Only ever capture on interfaces you own.

---

## 🧠 Today's Takeaway

tcpdump turns "what did the tool say?" into "what actually happened on the wire?". An idle interface is never silent, so capturing blindly mostly records noise, which is the reason filters exist. The basics worth keeping: pick the interface with `-i`, use `-n` for clean numeric output, read the TCP flags (`[S]`, `[S.]`, `[.]`, `[P.]`, `[F.]`, `[R.]`) to follow a connection's life, and read saved captures back with `-r`.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 11: tcpdump Part 2: filters (host, port, protocol)**
