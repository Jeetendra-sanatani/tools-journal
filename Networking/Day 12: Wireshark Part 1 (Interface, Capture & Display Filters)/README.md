# 🦈 Networking Day 12: Wireshark Part 1 (Interface, Capture & Display Filters)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_12%2F15-blue?style=for-the-badge" alt="Day 12"/>
  <img src="https://img.shields.io/badge/tool-Wireshark-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> On Day 10 tcpdump printed packets as lines of text. Wireshark shows the same packets decoded layer by layer, color-coded and clickable, and lets me hide most of them without losing any. 🦈

---

## 🏆 Day 10 Recap — Challenge Solutions

*(Day 11 is still pending, so this recap is from the last finished day.)*

**Challenge 1 (The Ten Strangers):** A network is never silent: ARP, DNS lookups and name-resolution attempts happen all the time. `-c 10` stops after the first 10 packets whatever they are, so background chatter can fill the quota. Filters solve that.

**Challenge 2 (Refused at the Packet Level):** A reset (`[R.]`) means the host is reachable but nothing listens on that port. It's the packet-level version of "Connection refused". A filtered port would give no reply at all.

**Challenge 3 (Names vs Numbers):** `-n` keeps tcpdump output numeric. Without it, tcpdump turns `127.0.0.1` into `localhost` and `8080` into `http-alt`, and can trigger extra DNS lookups that add noise.

---

## 🎯 Mission Briefing

Reading raw tcpdump lines works, but it doesn't scale. Wireshark takes the same capture and decodes it: every packet is split into layers, request and response are linked together, and a filter bar decides what's visible. Today: capture on two interfaces, filter, and read packets layer by layer.

```
🦈 MISSION: See the Packets Properly
──────────────────────────────────────────
[x] Capture on loopback and on eth0
[x] Narrow the view with display filters
[x] Read a packet layer by layer in the details pane
[x] Compare a filtered view with the full capture
[ ] SYN-flag filters (tcp.flags.syn): still to do
──────────────────────────────────────────
STATUS: Networking Day 12 — Done (a few filters still pending)
```

---

## ⚡ Quick Theory

**Wireshark** captures the same packets tcpdump does and adds a decoder: each packet is split into its layers (Frame, Ethernet, IP, then TCP, UDP or ICMP, then the application protocol) and shown in plain terms.

**Three panes.** The packet list has one row per packet, colored by protocol. The packet details pane shows the selected packet layer by layer. The packet bytes pane shows the raw hex and ASCII. In my layout the details pane is bottom-left and the bytes pane bottom-right. Clicking a field in the details pane highlights its bytes, and the status bar shows that field's filter name (for example `eth.dst.ig`), which is how to find out what to type into the filter bar.

**Capture filter vs display filter.** A capture filter (BPF syntax, the same as tcpdump's `port 8080`) is set before capturing, and packets that don't match are never saved. A display filter (Wireshark's own syntax, like `tcp.port == 8080`) is typed after capturing. It only hides packets, and they're all still in the file. That's why the status bar can say `Packets: 49 · Displayed: 8`: 49 captured, 8 shown.

**Request and response are linked.** ICMP rows say `(reply in 37)` and `(request in 36)`, and HTTP packets carry `Request in frame` and `Time since request`. Wireshark also stitches data that arrived in several TCP segments back together (`[2 Reassembled TCP Segments ...]`).

**Pick the interface.** `Loopback: lo` shows my machine talking to itself. `eth0` shows my real network.

---

## 💻 Lab: Filters + My Real Output

*(Machine: Kali Linux, user `ruin`. Long option lists trimmed with `...`)*

### 🔁 Part A: a first capture on loopback

I captured on `Loopback: lo` while running `curl -s http://127.0.0.1:8080/ > /dev/null` three times against a local `python3 -m http.server 8080`, and saved it as `basic_capture.pcapng`. The status bar reads `Packets: 36 · Displayed: 36 (100.0%) · Dropped: 0`. The first conversation (the other two look identical and start at 1.558 s and 2.837 s, from source ports 55148 and 55150):

```text
No.  Time         Protocol  Info
 1   0.000000000  TCP       55132 -> 8080 [SYN] Seq=0 Win=65495 Len=0 ...
 2   0.000014141  TCP       8080 -> 55132 [SYN, ACK] Seq=0 Ack=1 Win=65483 Len=0 ...
 3   0.000024782  TCP       55132 -> 8080 [ACK] Seq=1 Ack=1 Win=65536 Len=0 ...
 4   0.000090781  HTTP      GET / HTTP/1.1
 5   0.000096025  TCP       8080 -> 55132 [ACK] Seq=1 Ack=79 Len=0 ...
 6   0.000788121  TCP       8080 -> 55132 [PSH, ACK] Seq=1 Ack=79 Len=188 ... [TCP PDU reassembled in 8]
 7   0.000815713  TCP       55132 -> 8080 [ACK] Seq=79 Ack=189 Len=0 ...
 8   0.000865159  HTTP      HTTP/1.0 200 OK  (text/html)
 9   0.000891483  TCP       55132 -> 8080 [ACK] Seq=79 Ack=14300 Len=0 ...
10   0.000934935  TCP       8080 -> 55132 [FIN, ACK] Seq=14300 Ack=79 Len=0 ...
11   0.001286875  TCP       55132 -> 8080 [FIN, ACK] Seq=79 Ack=14301 Len=0 ...
12   0.001301764  TCP       8080 -> 55132 [ACK] Seq=14301 Ack=80 Len=0 ...
```
These are the same 12 packets per conversation that `tcpdump -r` printed for this file on Day 10, now with the HTTP rows highlighted in light green and Wireshark decoding the request and response for me.

### 🔍 Part B: display filters

```text
tcp.port == 8080            ->  Displayed: 36 of 36 (100.0%)   [loopback, 3 curl requests]
http && tcp.port == 8080    ->  Displayed: 6 of 36 (16.7%)     [loopback]
icmp                        ->  Displayed: 8 of 49 (16.3%)     [eth0 capture #2]
icmp || dns                 ->  Displayed: 14 of 18 (77.8%)    [eth0 capture #1]
```
Everything on loopback matched `tcp.port == 8080` because that was the only traffic there. Adding `http` cut it to 6 packets: the 3 `GET` requests and the 3 `200 OK` responses. The other 30 (handshakes, ACKs, FINs) are hidden, not deleted.

### 📦 Part C: reading single packets

**The request (frame 4, loopback):**
```text
Frame 4: 144 bytes on wire, interface lo
Ethernet II   Src: 00:00:00:00:00:00   Dst: 00:00:00:00:00:00        (loopback has no real MACs)
IPv4          Src: 127.0.0.1   Dst: 127.0.0.1
TCP           Src Port: 55132   Dst Port: 8080   Seq: 1   Ack: 1   Len: 78
HTTP          GET / HTTP/1.1
              Host: 127.0.0.1:8080
              User-Agent: curl/8.21.0
              Accept: */*
              [Response in frame: 8]
              [Full request URI: http://127.0.0.1:8080/]
```

**The response (frame 8, loopback):**
```text
Frame 8: 14177 bytes on wire, interface lo
TCP           Src Port: 8080   Dst Port: 55132   Seq: 189   Ack: 79   Len: 14111
              [2 Reassembled TCP Segments (14299 bytes): #6(188), #8(14111)]
HTTP          HTTP/1.0 200 OK
              Server: SimpleHTTP/0.6 Python/3.14.7
              Date: Thu, 08 Oct 2026 04:37:42 GMT
              Content-type: text/html
              Content-Length: 14111
              Last-Modified: Thu, 01 Oct 2026 04:25:28 GMT
              [Request in frame: 4]
              [Time since request: 774.378 microseconds]
              File Data: 14111 bytes   (line-based text data: text/html, 64 lines)
```
A few things worth pulling out of this:

- The client is `curl/8.21.0` and the server announces itself as `SimpleHTTP/0.6 Python/3.14.7`. Both identify themselves in plain text, the same way the IIS server did on Day 03.
- The server answered in 774 microseconds, and Wireshark calculated that for me from the two packets.
- The response arrived in two TCP segments (188 bytes of headers, then 14111 bytes of page), and Wireshark reassembled them into one 14299-byte message.
- `Last-Modified: Thu, 01 Oct 2026 04:25:28 GMT` is 09:55:28 IST on 1 October. That is the moment `wget` saved `index.html` on Day 03, so this server was serving the exact file I downloaded then.

**A ping on eth0 (frame 36):**
```text
Frame 36: 98 bytes on wire, interface eth0, Arrival Time Oct 10, 2026 09:38:41.904408178 IST
Ethernet II   Src: VMware_d0:b1:af (00:0c:29:d0:b1:af)   Dst: VMware_f7:fa:94 (00:50:56:f7:fa:94)
IPv4          Src: 192.168.80.136   Dst: 192.168.80.2   Header Length: 20 bytes   Total Length: 84
ICMP          Type: 8 (Echo request)   Code: 0   Checksum: 0xdba7 [correct]
              Identifier: 0x7c8f   Sequence Number: 4   [Response frame: 37]
              Data: 56 bytes (a timestamp plus 40 bytes of pattern)
```
The source MAC `00:0c:29:d0:b1:af` is my `eth0` from Day 10's `ip addr`, and the destination `00:50:56:f7:fa:94` is the gateway's MAC from the ARP reply in the same capture. The IP `Total Length: 84` is Day 01's `56(84) bytes of data` from `ping`: 56 data bytes + 8 ICMP header + 20 IP header. The frame is 98 bytes because Ethernet adds 14 more.

### 🌐 Part D: capturing on eth0

I pinged my gateway (`192.168.80.2`) and looked up `example.com` instead of the `1.1.1.1` and `google.com` in the lab sheet, which works just as well for the lesson. I ended up with two eth0 captures.

**Capture #1 (18 packets, filter `icmp || dns`, 14 shown):**
```text
No.  Time          Source           Destination      Info
 1    0.000000000  192.168.80.136   192.168.80.2     ICMP  Echo request  id=0x7c90 seq=1  ttl=64  (reply in 4)
 4    0.000426499  192.168.80.2     192.168.80.136   ICMP  Echo reply    id=0x7c90 seq=1  ttl=128 (request in 1)
 5    1.018715460  192.168.80.136   192.168.80.2     ICMP  Echo request  seq=2 (reply in 6)
 6    1.019102734  192.168.80.2     192.168.80.136   ICMP  Echo reply    seq=2
 7    2.039004385  192.168.80.136   192.168.80.2     ICMP  Echo request  seq=3 (reply in 8)
 8    2.044087323  192.168.80.2     192.168.80.136   ICMP  Echo reply    seq=3
 9    3.040602616  192.168.80.136   192.168.80.2     ICMP  Echo request  seq=4 (reply in 10)
10    3.040845214  192.168.80.2     192.168.80.136   ICMP  Echo reply    seq=4
13    6.880662644  192.168.80.136   192.168.80.2     DNS   Standard query 0x2bf4 A example.com OPT
14    6.892673340  192.168.80.2     192.168.80.136   DNS   Standard query response 0x2bf4 A example.com A 172.66.147.243 A 104.20.23.154 OPT
15    6.893663140  192.168.80.136   192.168.80.2     DNS   Standard query 0xef90 AAAA example.com OPT
16   11.898942450  192.168.80.136   192.168.80.2     DNS   Standard query 0xef90 AAAA example.com OPT
17   16.903327730  192.168.80.136   192.168.80.2     DNS   Standard query 0xef90 AAAA example.com OPT
18   21.913087817  192.168.80.136   192.168.80.2     DNS   Standard query 0xef90 AAAA example.com OPT
```
Calculated from the Time column, the four ping round trips took about 0.43, 0.39, 5.08 and 0.24 ms, so the third one was a clear outlier. My requests carry `ttl=64` and the gateway's replies `ttl=128`, the same pattern as the gateway pings on Day 01. The `A` lookup for `example.com` was answered in about 12 ms with two addresses. The `AAAA` (IPv6) lookup was sent four times, about 5 seconds apart, and no response to it appears anywhere in the capture. I haven't found out why the gateway never answered it, only that the IPv4 lookup worked fine.

**Capture #2 (49 packets, saved as `wireshark_eth0AG1QW3.pcapng`):** the `icmp` filter showed 8 packets (4 requests and 4 replies, `id=0x7c8f`). Calculated round trips were about 1.65, 0.59, 0.28 and 0.20 ms. The first one was slowest, and an ARP packet (frame 28, `192.168.80.136 is at 00:0c:29:d0:b1:af`) sits between the first request and its reply, which probably accounts for the extra time.

With the filter cleared, only 8 of the 49 packets were my pings. The rows I could see were background chatter:

```text
ARP    28      192.168.80.136 is at 00:0c:29:d0:b1:af
ARP    41      192.168.80.2 is at 00:50:56:f7:fa:94
NBNS   17-19   192.168.80.1 -> 192.168.80.255   Name query NB WPAD<00>
MDNS   1-4, 10-13   192.168.80.1 -> 224.0.0.251 (and an fe80:: address -> ff02::fb)
                     Standard query 0x0000 A / AAAA wpad.local
LLMNR  8       fe80:: address -> ff02::1:3   Standard query 0x734d AAAA wpad
```
Three different protocols (NetBIOS, mDNS, LLMNR) were all asking the local network for a host called `wpad`. `192.168.80.1` looks like the VMware host's adapter, which showed up with a VMware MAC in the Day 04 host discovery.

---

## 🧪 What I Actually Found

- [x] Loopback capture of 3 curl requests = 36 packets, 12 per request (handshake, GET, 200 OK in two segments, FIN teardown)
- [x] `tcp.port == 8080` showed 36 of 36; `http && tcp.port == 8080` showed 6 of 36
- [x] Request and response fields read directly in the details pane, plus `Time since request: 774.378 microseconds`
- [x] The served page's `Last-Modified` time matched my Day 03 `wget` download
- [x] 4 pings to the gateway = 8 ICMP packets; requests `ttl=64`, replies `ttl=128`; one 5.08 ms outlier
- [x] `example.com` `A` lookup answered in about 12 ms; the `AAAA` lookup got no answer after 4 tries
- [x] Unfiltered eth0 view showed ARP plus NBNS, mDNS and LLMNR queries for `wpad`
- [ ] `tcp.flags.syn == 1` and `tcp.flags.syn == 1 && tcp.flags.ack == 0`: not run yet
- [ ] `http` on its own and `ip.addr == 127.0.0.1`: not run yet

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: 36 Packets, 3 Requests**
> Three simple curl requests produced 36 packets, and `http && tcp.port == 8080` kept only 6. Where do the 12 packets per request come from, and why only 2 HTTP packets per request?

<details>
<summary>My answer</summary>

Per request: 3 packets of handshake (`[S]`, `[S.]`, `[.]`), 2 for the `GET` and its ACK, 2 for the response headers (188 bytes) and its ACK, 2 for the page body (14111 bytes) and its ACK, and 3 to close (`[F.]`, `[F.]`, `[.]`). That's 12. The `http` filter only keeps packets Wireshark decodes as HTTP: the `GET` (frame 4) and the `200 OK` (frame 8, where the two response segments were reassembled). Frame 6 is plain TCP (`TCP PDU reassembled in 8`), which is why only 2 per request survive.

</details>

> **🥊 Challenge 2: The Missing Answer**
> The `AAAA` query for `example.com` was sent four times, about 5 seconds apart, with no response, while the `A` query was answered in 12 ms. Was the network broken?

<details>
<summary>My answer</summary>

No. The pings to the gateway worked and the `A` lookup got an answer, so the network and the DNS server were reachable. Only the IPv6 lookup went unanswered, and the resolver kept retrying at a fixed timeout (5 seconds is a common default). It's the Day 01 lesson again: "ping works" doesn't mean "name resolution works", and a partly failing lookup shows up as delay rather than as a clean error. I haven't worked out why the `AAAA` query got no reply.

</details>

> **🥊 Challenge 3: Two TTLs**
> My ping requests show `ttl=64` and the replies `ttl=128`. Why different, and where have I seen this before?

<details>
<summary>My answer</summary>

TTL is set by whoever sends the packet. My Linux machine starts at 64 and the gateway starts at 128. The gateway is on my own subnet with no router in between, so the value arrives unchanged. It's the same `ttl=64` / `ttl=128` pairing from the gateway pings on Day 01. As on Day 01, it's only a hint about the sender, not proof.

</details>

---

## 🧩 Quick Brain Check

1. When does a capture filter apply, and when does a display filter apply? Which one can I change after capturing?
2. Why does `http && tcp.port == 8080` show 6 packets out of 36?
3. Which two fields let me jump from an HTTP request to its response, and from a ping request to its reply?
4. Which field of the ICMP packet says it's a ping request rather than a reply?
5. What do ARP, NBNS, mDNS and LLMNR have in common?

---

## 🐛 Errors / Gotchas I Hit

- The SYN-flag filters (`tcp.flags.syn == 1`, and the version with `&& tcp.flags.ack == 0`) weren't run, so I haven't confirmed the difference between them yet.
- The lab sheet said to ping `1.1.1.1` and look up `google.com`. I pinged the gateway and looked up `example.com` instead, which is fine for the lesson but means the numbers differ from the sheet.
- The two eth0 captures (18 and 49 packets) are separate sessions with different ping IDs (`0x7c90` and `0x7c8f`), so counts and timings shouldn't be compared across them.
- The loopback screenshots came from an earlier session (`basic_capture.pcapng`), not from the day's eth0 captures.

---

## 🔐 Security Relevance

A capture shows exactly what each side says in plain text: the client tool (`curl/8.21.0`), the server software and version (`SimpleHTTP/0.6 Python/3.14.7`), and the page itself. The same applies to any unencrypted protocol on a shared network. The `wpad` queries are a known weak spot too. Name lookups sent by multicast or broadcast (LLMNR, mDNS, NetBIOS) can be answered by any machine on the segment, which is why attackers abuse them in authorized pentests and why a common hardening step is to turn LLMNR and NetBIOS name resolution off where they aren't needed. Only ever capture on interfaces and networks you own.

---

## 🧠 Today's Takeaway

Wireshark and tcpdump capture the same packets. What Wireshark adds is decoding, color, request-to-response links, and a filter bar that hides packets without losing them. A display filter only changes the view, which is why 49 packets can shrink to 8 and come back with one click. And a quiet-looking interface isn't quiet: only 8 of 49 packets were my pings.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 13: Wireshark Part 2: Follow TCP Stream, reading DNS & HTTP** (Day 11, tcpdump filters, is still pending)
