# 📡 Networking Day 01: ping, traceroute & mtr

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_01%2F15-blue?style=for-the-badge" alt="Day 01"/>
  <img src="https://img.shields.io/badge/tools-ping_%7C_traceroute_%7C_mtr-orange?style=for-the-badge" alt="Tools"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> First tools of the networking phase. Before scanning or sniffing anything, you need to answer the simplest question in networking: **can I reach it, and how does my traffic get there?** 📡

---

## 🎯 Mission Briefing

Every network problem starts with the same three questions:
1. Is the target **alive**? → `ping`
2. What **path** does my traffic take? → `traceroute`
3. **Where** along that path is it slow or dropping packets? → `mtr`

```
📡 MISSION: Test Reachability & Trace the Path
──────────────────────────────────────────
[x] Ping loopback, gateway and the internet
[x] Tell a DNS problem from a connectivity problem
[x] Trace the route to a destination
[x] Read an mtr report (loss and latency per hop)
──────────────────────────────────────────
STATUS: Networking Day 01 — Done
```

---

## ⚡ Quick Theory

**ping** sends an ICMP "echo request" and waits for an "echo reply". It tells you: is the host reachable, how long the round trip takes (latency), and whether packets get lost.

**Reading a ping reply line:**
```text
64 bytes from 1.1.1.1: icmp_seq=1 ttl=128 time=23.0 ms
                                   │       └── round-trip latency
                                   └── TTL: hops left before the packet is dropped
```

**TTL (Time To Live)** starts at a fixed number and drops by 1 at every router. Common starting values: `64` (Linux/macOS), `128` (Windows), `255` (many network devices). It is only a *hint* about the OS, never proof — routers and NAT devices can also show 128.

**traceroute** uses that TTL trick on purpose: it sends packets with TTL 1, 2, 3... Each router that drops one replies "time exceeded", which reveals that router. That is how you see the path, hop by hop.

**mtr** = ping + traceroute combined, running continuously and showing **loss % and latency for every hop**. It is the best tool for "the internet feels slow, where is the problem?"

**The troubleshooting trick worth remembering:**
```text
ping 1.1.1.1      works
ping google.com   also works   →   confirms DNS is working correctly
```
If `ping <IP>` works but `ping <name>` fails, that is a DNS problem, not a connectivity problem.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🔍 Finding my gateway
```bash
$ ip route
default via 192.168.80.2 dev eth0 proto dhcp src 192.168.80.136 metric 100
192.168.80.0/24 dev eth0 proto kernel scope link src 192.168.80.136 metric 100
```
My gateway is `192.168.80.2`.

### 📡 ping: loopback
```bash
$ ping -c 4 127.0.0.1
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.042 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.089 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.050 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.095 ms

--- 127.0.0.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3077ms
rtt min/avg/max/mdev = 0.042/0.069/0.095/0.023 ms
```

### 📡 ping: gateway
```bash
$ ping -c 4 192.168.80.2
PING 192.168.80.2 (192.168.80.2) 56(84) bytes of data.
64 bytes from 192.168.80.2: icmp_seq=1 ttl=128 time=0.319 ms
64 bytes from 192.168.80.2: icmp_seq=2 ttl=128 time=0.678 ms
64 bytes from 192.168.80.2: icmp_seq=3 ttl=128 time=0.498 ms
64 bytes from 192.168.80.2: icmp_seq=4 ttl=128 time=0.765 ms

--- 192.168.80.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3046ms
rtt min/avg/max/mdev = 0.319/0.565/0.765/0.171 ms
```

### 📡 ping: internet, by IP
```bash
$ ping -c 4 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=128 time=23.0 ms
64 bytes from 1.1.1.1: icmp_seq=2 ttl=128 time=22.6 ms
64 bytes from 1.1.1.1: icmp_seq=3 ttl=128 time=22.0 ms
64 bytes from 1.1.1.1: icmp_seq=4 ttl=128 time=22.1 ms

--- 1.1.1.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 22.020/22.450/23.022/0.400 ms
```

### 📡 ping: internet, by name
```bash
$ ping -c 4 google.com
PING google.com (142.251.220.46) 56(84) bytes of data.
64 bytes from pnbomb-ba-in-f14.1e100.net (142.251.220.46): icmp_seq=1 ttl=128 time=16.9 ms
64 bytes from pnbomb-ba-in-f14.1e100.net (142.251.220.46): icmp_seq=2 ttl=128 time=17.3 ms
64 bytes from pnbomb-ba-in-f14.1e100.net (142.251.220.46): icmp_seq=3 ttl=128 time=16.8 ms
64 bytes from pnbomb-ba-in-f14.1e100.net (142.251.220.46): icmp_seq=4 ttl=128 time=16.6 ms

--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 16.626/16.892/17.341/0.271 ms
```
`google.com` resolved to `142.251.220.46` and replied successfully — DNS and connectivity both working.

### ❌ ping: deliberate failure
```bash
$ ping -c 4 192.0.2.1
PING 192.0.2.1 (192.0.2.1) 56(84) bytes of data.

--- 192.0.2.1 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3060ms
```
`192.0.2.1` is a reserved documentation address. It never replies, so this shows what a genuine failure looks like: 100% loss, no replies logged at all.

### 🛣️ traceroute
```bash
$ traceroute -n 1.1.1.1
 1  192.168.80.2   0.800 ms  1.758 ms  1.737 ms
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  * * *
13  * * *
```
Only hop 1 (my own gateway) replied. Every hop after that showed `* * *`.

### 📊 mtr report
```bash
$ mtr -rwbc 10 1.1.1.1
Start: 2026-09-29T10:15:17+0530
HOST: Devil                Loss%   Snt   Last   Avg  Best  Wrst StDev
 1. _gateway (192.168.80.2) 0.0%    10    0.4   0.8   0.3   1.1   0.3
 2. 192.168.10.99           0.0%    10    1.9   1.9   1.0   2.4   0.4
 3. one.one.one.one (1.1.1.1) 20.0%  10    3.3   3.9   3.3   4.6   0.5
```

---

## 🧪 What I Actually Found

- [x] Ping loopback, gateway and the internet
- [x] Tell a DNS problem from a connectivity problem
- [x] Trace the route to a destination
- [x] Read an mtr report (loss and latency per hop)

---

## 🎯 Mini Challenges — My Answers

> **🥊 Challenge 1: DNS or Connectivity?**
> `ping 8.8.8.8` works but `ping google.com` says "Temporary failure in name resolution". What is broken, and which file would you check first?

<details>
<summary>My answer</summary>

DNS is broken, not connectivity — the machine can reach the internet (IP ping works), it just can't translate names to IPs. First file to check: `/etc/resolv.conf` (which DNS server is configured), and confirm that server is actually reachable.

</details>

> **🥊 Challenge 2: The TTL Hint**
> One reply shows `ttl=64` and another shows `ttl=128`. What might that suggest, and why shouldn't you fully trust it?

<details>
<summary>My answer</summary>

`ttl=64` on my own loopback suggests a Linux-based system (common starting TTL 64). `ttl=128` on the gateway and internet hosts suggests something Windows-based, or more likely a device whose starting TTL is 128 by design (many routers/appliances do this). It's just a hint because the actual value I see also depends on how many hops it already crossed, and different OSes/devices don't always follow the "textbook" starting values.

</details>

> **🥊 Challenge 3: The Scary Hop**
> `mtr` shows 20% loss at the final hop (hop 3, `one.one.one.one`), while earlier hops show 0% loss. Is there a real problem?

<details>
<summary>My answer</summary>

Not necessarily. The loss showed up at the DESTINATION itself, not at a hop in the middle of the path — the earlier hops (gateway, ISP hop) had 0% loss. This usually means the destination is rate-limiting or deprioritizing ICMP replies under load, not that the network path is actually dropping traffic. If a middle hop had shown loss while the final hop was clean, that would be more concerning.

</details>

---

## 🧩 Quick Brain Check

1. Which protocol does `ping` use, and why does that matter if a firewall blocks it?
2. What does `-c 4` do in `ping -c 4 google.com`?
3. How does traceroute discover each router along the path?
4. What does `* * *` in a traceroute line mean, and does it always mean trouble?
5. What does mtr show that plain `ping` and `traceroute` don't?

---

## 🐛 Errors / Gotchas I Hit

- First attempt at pinging the gateway, I used `192.168.1.1` instead of my actual gateway `192.168.80.2` (from `ip route`). Got a reply anyway, but it wasn't testing what I thought it was — always confirm the gateway IP with `ip route` first, don't assume it.
- `traceroute -n 1.1.1.1` showed `* * *` for every hop after my own gateway. This is very likely ICMP/UDP probes being blocked somewhere along the path (common on VPN/NAT setups like this one) — not a broken connection, since `ping` and `mtr` to the same address both worked fine.
- `mtr` showed 20% loss, but only at the final destination hop, not along the path — see Challenge 3 above.

---

## 🔐 Security Relevance

`ping` is often the very first step of recon (host discovery), and `traceroute` reveals network structure (routers, hops, sometimes firewalls). Defenders use the same tools to confirm that a firewall rule does what it should — for example, that a blocked host really is unreachable.

---

## 🧠 Today's Takeaway

`ping` asks "are you there?", `traceroute` asks "what's the path?", and `mtr` asks "where along the path is it going wrong?". Testing by IP first and then by name (like `1.1.1.1` then `google.com`) is the fastest way to separate a DNS problem from a real connectivity problem. And loss showing up only at the very last hop is usually the destination itself, not the network in between.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 02: dig, nslookup & whois**
