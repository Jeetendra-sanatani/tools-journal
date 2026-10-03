# 🎯 Networking Day 04: nmap Part 1 (Host Discovery & Basic Scans)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_04%2F15-blue?style=for-the-badge" alt="Day 04"/>
  <img src="https://img.shields.io/badge/tool-nmap-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The first real scanning tool of this journey. Before anything else, nmap answers two questions: who's alive on this network, and what's listening on them? 🎯

---

## 🏆 Day 03 Recap — Challenge Solutions

**Challenge 1 (Headers as Recon):** `Server`, `X-Powered-By`, and version-specific headers reveal the OS, web server, and framework — a full tech fingerprint without reading any HTML.

**Challenge 2 (Session Cookie Mismatch):** Not a bug — every stateless request with no saved cookie jar gets a fresh session ID from the server.

**Challenge 3 (curl vs wget, Pick One):** `curl -s -o /dev/null -w "%{http_code}\n" <url>` — built for scripting, returns just the status code.

---

## 🎯 Mission Briefing

Before you can scan ports on anything, you first need to know what's even alive on a network. Today: host discovery with `-sn`, and the default behavior of a basic nmap scan.

```
🎯 MISSION: Discover Hosts & Run Basic Scans
──────────────────────────────────────────
[x] Find my own local network range
[x] Discover live hosts with -sn (no port scan)
[x] Run a default scan against my own machine
[x] Run scans against scanme.nmap.org (permitted target)
──────────────────────────────────────────
STATUS: Networking Day 04 — Done
```

---

## ⚡ Quick Theory

**`nmap -sn`** does host discovery only — no port scanning at all. It just answers "who's up?" using a mix of ICMP, ARP (on local networks), and TCP probes, depending on what's reachable.

**A default `nmap <target>`** (no flags) scans the **top 1000 most common TCP ports** — not all 65535. This is a deliberate speed/thoroughness tradeoff; a full `-p-` scan of all ports takes much longer.

**The three port states that matter:**
```
open      -> something is actively listening and responded
closed    -> the port is reachable, but nothing is listening there
filtered  -> nmap couldn't tell; a firewall is most likely blocking the probe
```

**Service names next to a port are a guess, not a guarantee.** nmap's default scan maps port numbers to their *commonly* associated service from a built-in list — it doesn't actually verify what's really running there unless you add `-sV` (service/version detection, which is Day 06's topic). A port showing `cisco-sccp` just means "port 2000 is usually Cisco SCCP" — it might not actually be that at all.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🗺️ Finding my network and discovering live hosts
```bash
$ ip route
default via 192.168.80.2 dev eth0 proto dhcp src 192.168.80.136 metric 100
192.168.80.0/24 dev eth0 proto kernel scope link src 192.168.80.136 metric 100

$ sudo nmap -sn 192.168.80.0/24
Nmap scan report for 192.168.80.1
Host is up (0.00032s latency).
MAC Address: 00:50:56:C0:00:08 (VMware)
Nmap scan report for _gateway (192.168.80.2)
Host is up (0.00026s latency).
MAC Address: 00:50:56:F7:FA:94 (VMware)
Nmap scan report for 192.168.80.254
Host is up (0.00029s latency).
MAC Address: 00:50:56:E6:A5:49 (VMware)
Nmap scan report for Devil.local (192.168.80.136)
Host is up.
Nmap done: 256 IP addresses (4 hosts up) scanned in 6.57 seconds
```
4 hosts found alive on a /24 (256 possible addresses): the gateway (`.2`), two other VMware-hosted addresses (`.1` and `.254` — likely the VM host and a DHCP/NAT helper), and my own machine (`Devil.local`, `.136`). All three others show VMware MAC prefixes, confirming this is an isolated VM network, not a shared/production one.

### 🔍 Scanning my own machine
```bash
$ nmap 127.0.0.1
Nmap scan report for localhost (127.0.0.1)
Host is up (0.0000060s latency).
Not shown: 999 closed tcp ports (reset)
PORT   STATE SERVICE
22/tcp open  ssh

Nmap done: 1 IP address (1 host up) scanned in 0.12 seconds
```
Only one port open out of the top 1000 checked: SSH. Out of curiosity I also tried `-sV` (service/version detection, a Day 06 topic) a step early:
```bash
$ nmap -sV 127.0.0.1
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 10.4p1 Debian 5 (protocol 2.0)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
This confirmed it's genuinely OpenSSH (not just a guess based on the port number) and even picked up the OS hint — a nice preview of what `-sV` adds.

### 🌐 Scanning scanme.nmap.org (the permitted target)
```bash
$ nmap -F scanme.nmap.org
Nmap scan report for scanme.nmap.org (45.33.32.156)
Not shown: 96 filtered tcp ports (no-response)
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
2000/tcp open  cisco-sccp
5060/tcp open  sip

Nmap done: 1 IP address (1 host up) scanned in 3.64 seconds

$ nmap -p 80,443 scanme.nmap.org
PORT    STATE    SERVICE
80/tcp  open     http
443/tcp filtered https
```
The fast scan (`-F`, top 100 ports) found 4 open ports. `22` and `80` are the expected, well-known services. `2000` and `5060` are just nmap's *guess* based on common usage (Cisco SCCP, SIP) — without `-sV` there's no proof that's actually what's running there. Port 443 showed `filtered`, meaning something (a firewall) is likely blocking the probe rather than the port genuinely being closed.

I also tried `nmap -sV scanme.nmap.org` out of curiosity, but it ran for several minutes without finishing — nmap itself warned `giving up on port because retransmission cap hit`. scanme.nmap.org is a shared public target that intentionally rate-limits aggressive scanning, so slow/incomplete results here are expected, not a problem with my setup.

---


### 🐢 Troubleshooting the slow scanme.nmap.org scan

The earlier `-sV` attempt never finished, so I tried narrowing down why:

```bash
$ nmap --host-timeout 30s scanme.nmap.org
Skipping host scanme.nmap.org (45.33.32.156) due to host timeout
Nmap done: 1 IP address (1 host up) scanned in 30.64 seconds
```
`--host-timeout 30s` alone wasn't enough — the full top-1000-port scan genuinely needs more than 30 seconds against this target, so nmap gave up on the whole host before finishing even one port.

```bash
$ nmap -T4 scanme.nmap.org
Warning: 45.33.32.156 giving up on port because retransmission cap hit (6).
Not shown: 962 closed tcp ports (reset), 33 filtered tcp ports (no-response)
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
2000/tcp open  cisco-sccp
5060/tcp open  sip
9929/tcp open  nping-echo

Nmap done: 1 IP address (1 host up) scanned in 97.13 seconds
```
`-T4` (a faster timing template) let the full top-1000 scan actually complete — 97 seconds instead of timing out — and it found a **5th open port** that the earlier fast scan missed: `9929/tcp`, identified as `nping-echo` (nmap's own echo-testing service, which the scanme.nmap.org maintainers run deliberately for people testing nmap's `nping` tool against it).

```bash
$ nmap -F -T4 --host-timeout 30s scanme.nmap.org
Not shown: 96 filtered tcp ports (no-response)
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
2000/tcp open  cisco-sccp
5060/tcp open  sip

Nmap done: 1 IP address (1 host up) scanned in 3.45 seconds
```
Combining `-F` (top 100 ports only) with `-T4` (faster timing) finished cleanly in 3.45 seconds. The lesson: a slow/stuck scan isn't always a sign of something broken — it's often a sign the scan needs either a narrower port range (`-F` or `-p`) or a faster timing template (`-T4`) to finish in a reasonable time against a rate-limiting target.

## 🧪 What I Actually Found

- [x] My subnet: `192.168.80.0/24`, gateway `192.168.80.2`
- [x] 4 hosts alive on that subnet (including my own machine)
- [x] My own machine: only port 22 (SSH) open
- [x] `scanme.nmap.org`: ports 22, 80, 2000, 5060 open (via `-F`); a full `-T4` scan also found port 9929 (nping-echo); port 443 filtered
- [x] Confirmed `-sV` adds real version detail (OpenSSH 10.4p1) vs. the default scan's guess
- [x] Fixed a stuck/slow scan against scanme.nmap.org by combining `-T4` with `-F`/`--host-timeout`

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Open vs Filtered**
> `nmap -p 80,443 scanme.nmap.org` showed port 80 as `open` and port 443 as `filtered`. What's the practical difference, and what does `filtered` most likely mean here?

<details>
<summary>My answer</summary>

`open` means something actively responded to the probe on port 80. `filtered` means nmap got no response at all and couldn't determine the port's real state — most likely a firewall is silently dropping probes to port 443, rather than the port being genuinely closed (a closed port actively replies with a reset; a filtered one stays silent).

</details>

> **🥊 Challenge 2: Trusting the Service Name**
> The fast scan showed port 2000 as `cisco-sccp`. Can you be certain that's actually what's running there?

<details>
<summary>My answer</summary>

No. Without `-sV`, nmap's service names come from a lookup table matching the port number to its *commonly* associated service — it never actually confirmed what's really listening on port 2000. Only `-sV` (service/version detection) actually probes the port and checks the real response to verify.

</details>

> **🥊 Challenge 3: Why scanme Was Slow**
> A full `-sV` scan against `scanme.nmap.org` ran for several minutes without finishing, with nmap warning about hitting a retransmission cap. Is this a problem with my setup?

<details>
<summary>My answer</summary>

No — scanme.nmap.org is a shared public target used by countless people learning nmap, and it deliberately rate-limits or drops excessive probes to stay available for everyone. Slow or incomplete aggressive scans against it are expected, not a sign of a broken local setup.

</details>

---

## 🧩 Quick Brain Check

1. What's the difference between `nmap -sn` and a normal `nmap <target>`?
2. Why does a default scan check only 1000 ports instead of all 65535?
3. What's the real difference between a `closed` port and a `filtered` port?
4. Why can't you fully trust a service name shown without `-sV`?
5. Why is it important to only scan machines you own or that explicitly permit it?

---

## 🐛 Errors / Gotchas I Hit

- I scanned `example.com` during this session out of curiosity. On reflection, that wasn't one of the explicitly permitted targets (own machine, own local network, or `scanme.nmap.org`) — `example.com` is IANA's documentation domain, not an open scanning target. Nothing harmful happened (just a basic port scan, no exploitation), but going forward I'm sticking strictly to the three permitted target types.
- `nmap -sV scanme.nmap.org` took far longer than expected and never finished in a reasonable time — this turned out to be scanme.nmap.org itself rate-limiting the probes, not a problem on my end. Fixed by combining `-T4` (faster timing) with either `-F` (fewer ports) or a realistic `--host-timeout` — see the troubleshooting section above.
- Service names like `cisco-sccp` and `sip` next to ports 2000/5060 are nmap's best guess from the port number alone, not a confirmed identification.

---

## 🔐 Security Relevance

Host discovery and basic port scanning is the literal first step of any network assessment — you can't test or defend what you don't know exists. This is exactly why unauthorized scanning (even "just a port scan") is taken seriously in real environments: the same `-sn` sweep that maps my own lab here is indistinguishable, from the target's point of view, from the first move of an actual attack.

---

## 🧠 Today's Takeaway

`-sn` finds who's alive, a default scan checks the top 1000 ports, and every result needs a grain of salt until verified — `open`/`closed`/`filtered` are nmap's best read of the situation, and a service name without `-sV` is a guess based on port number alone, not proof. And `scanme.nmap.org` being slow under heavy scanning is itself a lesson in how rate-limiting defenses work.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 05: nmap Part 2 — scan types, speed & port ranges**
