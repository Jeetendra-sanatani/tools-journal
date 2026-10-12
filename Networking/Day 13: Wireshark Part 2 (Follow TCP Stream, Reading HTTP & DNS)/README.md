# 🔬 Networking Day 13: Wireshark Part 2 (Reading HTTP & DNS Traffic)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_13%2F15-blue?style=for-the-badge" alt="Day 13"/>
  <img src="https://img.shields.io/badge/tool-Wireshark-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 12 was about capturing and filtering. Day 13 is about reading what's inside: web requests, DNS answers, and the difference between traffic Wireshark can read and traffic it can't. 🔬

---

## 🏆 Day 12 Recap — Challenge Solutions

**Challenge 1 (36 Packets, 3 Requests):** 12 packets per request: 3 for the handshake, 2 for the GET and its ACK, 2 for the response headers and ACK, 2 for the page body and ACK, and 3 to close. The `http` filter keeps only the GET and the reassembled `200 OK`, which is 2 per request.

**Challenge 2 (The Missing Answer):** The network wasn't broken. Only the `AAAA` lookup went unanswered and the resolver retried at a fixed timeout. "Ping works" doesn't mean "name resolution works".

**Challenge 3 (Two TTLs):** The sender sets the TTL: my Linux machine starts at 64, the gateway at 128. They share a subnet, so the value arrives unchanged. It's a hint, not proof.

---

## 🎯 Mission Briefing

Wireshark's real value shows when I stop looking at packet counts and start reading fields: what a client asked for, what a server answered, how long it took, and what's simply unreadable from the wire.

```
🔬 MISSION: Read the Conversation
──────────────────────────────────────────
[x] Filter HTTP requests and responses
[x] Read a DNS response in the details pane
[x] Compare readable traffic with encrypted traffic in a long capture
[ ] Follow a TCP stream: not captured yet
[ ] Export a page from the capture: attempted, the list was empty
[ ] Statistics (Conversations, Protocol Hierarchy): not captured yet
──────────────────────────────────────────
STATUS: Networking Day 13 — Partly done (3 items pending)
```

---

## ⚡ Quick Theory

**HTTP filters.** `http.request` and `http.response` select the two sides of a web exchange, and `||` combines them. Plain HTTP is decoded for me: method, path, headers, status code.

**Anatomy of a DNS response.** The `Transaction ID` pairs a response with its query. `Flags: 0x8180` means "this is a response, recursion was asked for, recursion is available", and Wireshark spells it out as `Standard query response, No error`. Four counters follow: Questions, Answer RRs, Authority RRs and Additional RRs. The extra record shown as `OPT` is the EDNS option. Two bracketed lines tie it together: `[Request In: N]` names the query's frame and `[Time: ...]` is the delay between the two.

**DNS is not encrypted.** In the packet bytes pane the name `example.com` is sitting there as plain ASCII, so anyone on the segment can see which names a machine looks up.

**Readable vs protected.** Plain HTTP on port 8080 is decoded down to the headers. QUIC (the UDP-based transport under HTTP/3) only shows `Protected Payload (KP0)` plus a connection ID. From the wire I can still see who talks to whom, when, and how much, but not what.

**Trouble gets its own colour.** Wireshark paints TCP problems such as retransmissions with a black background and red text, so they stand out in a long capture.

**Still to do:** *Follow TCP Stream* rebuilds a whole conversation as text (red = client, blue = server), and *Export Objects → HTTP* rebuilds files that crossed the wire in plain HTTP. Both are on the pending list below.

---

## 💻 Lab: Filters + My Real Output

*(Machine: Kali Linux, user `ruin`. Loopback data comes from `basic_capture.pcapng`, DNS and the long capture from `wireshark_eth0MAE1W3.pcapng`)*

### 🌐 HTTP on loopback

```text
http.response || http.request   ->  Displayed: 6 of 36 (16.7%)
```
```text
No.   Time          Info
  4   0.000090781   GET / HTTP/1.1
  8   0.000865159   HTTP/1.0 200 OK  (text/html)
 16   1.558825097   GET / HTTP/1.1
 20   1.559495844   HTTP/1.0 200 OK  (text/html)
 28   2.837173795   GET / HTTP/1.1
 32   2.838154168   HTTP/1.0 200 OK  (text/html)
```
Calculated from the Time column, the server answered the three requests in about 774 µs, 671 µs and 980 µs. The first one matches the `Time since request: 774.378 microseconds` Wireshark showed on Day 12.

The header sizes add up exactly. Frame 28 (the third GET) shows `Total Length: 130`, and frame 20 (the second `200 OK`) shows `Total Length: 14163`. Subtracting a 20-byte IP header and a 32-byte TCP header (20 plus the 12-byte timestamp option seen in the Day 10 tcpdump lines) leaves 78 and 14111, which are the request size and the page size (`Content-Length: 14111`) from Day 12.

In the packet list, the margin beside frame 28 draws a bracket around frames 25 to 36 (that conversation, from SYN to the last ACK) and arrows linking the GET at 28 to its `200 OK` at 32.

### 📦 Export Objects (attempt)

I opened `File → Export Objects → HTTP...`. The **Wireshark · Export · HTTP object list** window appeared with its columns (Packet, Hostname, Content Type, Size, Filename), but the list was empty. The **Text Filter** box contained `~/Desktop/wireshark_practice/`. I had typed a folder path there, probably meaning a save location, but that box filters the list by text, so no row matched. Clearing it, selecting the row and pressing **Save** is the fix. No file has been exported yet.

### 🧭 DNS on eth0

Live capture on `eth0` with the filter `dns.flags.response == 1`:
```text
Packets: 28 · Displayed: 2 (7.1%)

No.  Time          Source        Destination      Info
 4   0.011373487   192.168.80.2  192.168.80.136   Standard query response 0xe7b6 A example.com A 104.20.23.154 A 172.66.147.243 OPT
 6   0.024386922   192.168.80.2  192.168.80.136   Standard query response 0xe671 AAAA example.com AAAA 2606:4700:10::ac42:93f3 AAAA 2606:4700:10::6814:179a OPT
```
The details of frame 4:
```text
Frame 4: 114 bytes on wire, interface eth0
Ethernet II   Src: VMware_f7:fa:94 (00:50:56:f7:fa:94)   Dst: VMware_d0:b1:af (00:0c:29:d0:b1:af)
IPv4          Src: 192.168.80.2   Dst: 192.168.80.136
UDP           Src Port: 53   Dst Port: 40339
DNS (response)  Transaction ID: 0xe7b6
                Flags: 0x8180 Standard query response, No error
                Questions: 1   Answer RRs: 2   Authority RRs: 0   Additional RRs: 1
                [Request In: 1]
                [Time: 11.373487 milliseconds]
```
A few things stand out:

- The gateway (`192.168.80.2`, the DNS server here) answered the `A` lookup in 11.4 ms with two addresses, the same two `example.com` returned on Day 12.
- This time the `AAAA` lookup was answered too, about 24 ms into the capture. On Day 12 the same lookup got no answer after four tries, so that silence wasn't permanent.
- The Ethernet addresses are the same pair as before: `00:50:56:f7:fa:94` (the gateway) and my own `eth0` MAC `00:0c:29:d0:b1:af`.
- Only `A` and `AAAA` for `example.com` were captured. The `google.com`, `MX` and non-existent-name lookups from the lab sheet are still to do.

### 📡 A longer eth0 capture (2402 packets)

I left the capture running for several minutes (`Packets: 2402 · Dropped: 0`), so it picked up much more than my lookups. Around the 329 to 336 second mark:
```text
No.   Time           Source            Destination       Protocol  Info
2305  329.134941991  142.251.151.119   192.168.80.136    QUIC      Protected Payload (KP0), DCID=a26f70
2306  329.135495541  192.168.80.136    142.251.151.119   QUIC      Protected Payload (KP0), DCID=f68a62b555df287c
2309  329.623355030  192.168.80.136    44.228.249.3      TCP       [TCP Retransmission] 41348 -> 443 [SYN] Seq=0 Win=64240 Len=0 ...
2310  329.623524227  192.168.80.136    44.228.249.3      TCP       [TCP Retransmission] 41340 -> 443 [SYN] Seq=0 Win=64240 Len=0 ...
2313  329.875502897  192.168.80.136    44.228.249.3      TCP       [TCP Retransmission] 41354 -> 443 [SYN] Seq=0 Win=64240 Len=0 ...
```
Two very different kinds of traffic:

- **QUIC:** many packets to and from `142.250.x.x`, `142.251.x.x` and `192.178.x.x` addresses (the `142.251.x.x` range is where `google.com` resolved on Day 02). Every one says only `Protected Payload (KP0)` plus a connection ID (`DCID`). Wireshark can't show what's inside.
- **Retransmitted SYNs:** from three source ports (41340, 41348, 41354) my machine kept sending connection requests to `44.228.249.3` on port 443, and Wireshark painted them black and red. No reply from that address appears in the rows I captured. For port 41340 the SYNs went out at 329.62 s, 330.64 s, 331.67 s and 333.68 s, so the gaps were about 1, 1 and 2 seconds, growing as the retries went on.

I don't know which program was trying to reach `44.228.249.3` or why it wasn't answering. Next time I can find out while it's happening with `ss -tnp state syn-sent` (Linux journal) and identify the address with `dig -x 44.228.249.3 +short` or `whois` (Networking Day 02).

---

## 🧪 What I Actually Found

- [x] `http.response || http.request` showed 6 of 36 packets, with server response times of about 0.77, 0.67 and 0.98 ms
- [x] IP `Total Length` values (130 and 14163) match the request and page sizes from Day 12 once the IP and TCP headers are subtracted
- [x] DNS response anatomy read directly: flags `0x8180`, 2 answers, `[Request In: 1]`, `[Time: 11.373487 milliseconds]`
- [x] The `AAAA` lookup for `example.com` was answered this time, unlike on Day 12
- [x] A long capture mixed readable and unreadable traffic: QUIC shows only `Protected Payload (KP0)`, while plain HTTP is fully decoded
- [x] Wireshark flagged repeated SYNs to `44.228.249.3:443` as `[TCP Retransmission]`, and the gaps between retries grew from about 1 s to about 2 s
- [ ] Follow TCP Stream (red/blue view, `tcp.stream eq N`): not captured
- [ ] Filters B1 to B4 from the lab sheet (`http.request.method == "GET"`, `http.response.code == 200`, `http.user_agent contains "curl"`, `http.host == ...`): not run
- [ ] Export Objects → HTTP: window opened but the list was empty, nothing exported
- [ ] `dig google.com`, the `MX` lookup and the non-existent name (`dns.flags.rcode == 3`): not captured
- [ ] Statistics → Conversations and Protocol Hierarchy: not captured

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Empty Export List**
> The Export Objects window opened with the right columns but no rows, even though the capture clearly contains HTTP responses. What went wrong, and how do I fix it?

<details>
<summary>My answer</summary>

The **Text Filter** box held `~/Desktop/wireshark_practice/`. That box filters the object list by text, and no entry contains that string, so every row was hidden. A folder path belongs in the Save dialog, not in the filter. Clear the Text Filter, select the response in the list, click **Save**, and choose the folder there.

</details>

> **🥊 Challenge 2: Readable vs Protected**
> The loopback capture shows `GET / HTTP/1.1` and `HTTP/1.0 200 OK` in full, while the eth0 capture shows thousands of QUIC packets that only say `Protected Payload (KP0)`. What can and can't I learn from the QUIC packets?

<details>
<summary>My answer</summary>

Plain HTTP carries its content unencrypted, so Wireshark decodes the method, path, headers and body. QUIC encrypts its payload, so only the outer parts are visible: the source and destination addresses, ports, packet sizes, timing and a connection ID (`DCID`). I can see who is talking to whom, when and how much, but not what is being said. That's the practical reason HTTPS and HTTP/3 matter on shared networks.

</details>

> **🥊 Challenge 3: Black and Red Rows**
> Several rows were black with red text and said `[TCP Retransmission] ... [SYN]`. What does that mean, and does it prove the data was corrupted?

<details>
<summary>My answer</summary>

It means my machine sent a SYN (a connection request), got no SYN-ACK back in time, and sent the same SYN again. It doesn't mean data was corrupted, because no data had been exchanged yet. It means the connection attempts weren't being answered. The cause could be a firewall silently dropping them (the same "filtered" behaviour nmap reported on Day 04), an unreachable host, or a blocked route. I haven't found out which one it was here.

</details>

---

## 🧩 Quick Brain Check

1. What does the Text Filter box in the Export Objects window do?
2. What do `[Request In: 1]` and `[Time: 11.373487 milliseconds]` tell me about a DNS response?
3. Why can Wireshark show a full HTTP request but only `Protected Payload (KP0)` for QUIC?
4. What does `dns.flags.response == 1` select, and what would `dns.flags.response == 0` show instead?
5. What does `[TCP Retransmission]` on a `[SYN]` packet tell me about the connection attempt?

---

## 🐛 Errors / Gotchas I Hit

- The Export Objects list was empty because I typed a folder path into the **Text Filter** box. That box filters the list; the save location is chosen in the Save dialog.
- Two screenshots didn't show what their names promised: `04-statistics.png` is the long eth0 capture (no Statistics window), and `01-follow-tcp-stream.png` is the loopback packet list (no Follow TCP Stream window). Those two parts are still pending.
- I left the capture running for several minutes (2402 packets), which buried my own lookups under unrelated traffic. Next time I should stop the capture right after generating the traffic I care about.
- I used `http.response || http.request` instead of the lab's filters, and only `example.com` instead of `google.com`, so some lab steps are still open.

---

## 🔐 Security Relevance

DNS lookups travel in the clear, so anyone on the same segment can see which names a machine asks for. Plain HTTP exposes the whole exchange, while QUIC and HTTPS hide the content but not the metadata (addresses, timing, volume). Repeated unanswered SYNs to the same outside address, like the ones to `44.228.249.3`, are the kind of pattern worth tracing back to a process. From the client's side, a firewall that silently drops traffic looks exactly like this: a SYN, silence, then retries with growing gaps. Only capture on interfaces and networks you own.

---

## 🧠 Today's Takeaway

Reading a capture means reading fields, not counting packets: a DNS response tells me the answer, the delay and the server that gave it; an HTTP response tells me the software and the size; and a protected payload tells me only who and how much. A long capture is also a reminder that a machine is never quiet, which is why a stop button and a filter matter.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 14: Project 1: network recon script** (Day 11, tcpdump filters, is still pending)
