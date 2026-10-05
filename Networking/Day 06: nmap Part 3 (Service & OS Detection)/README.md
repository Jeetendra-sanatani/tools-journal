# 🔬 Networking Day 06: nmap Part 3 (Service & OS Detection)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_06%2F15-blue?style=for-the-badge" alt="Day 06"/>
  <img src="https://img.shields.io/badge/tool-nmap-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 05 compared HOW nmap scans. Day 06 goes further: not just "is this port open", but "what's actually running on it, and what OS is underneath it all?" 🔬

---

## 🏆 Day 05 Recap — Challenge Solutions

**Challenge 1 (The Suspended Scan):** Ctrl+Z only suspends a job, it doesn't kill it. Check with `jobs`, resume with `fg`, or properly end it with `kill %1`.

**Challenge 2 (A Fair Comparison):** A run that failed at DNS resolution isn't a valid timing result — resolve the IP first or confirm DNS succeeded before trusting the numbers.

**Challenge 3 (The Cleanest UDP Result):** `closed` is an active, confirmed ICMP reply. `open|filtered` means no response at all — nmap genuinely can't tell open-but-silent from blocked.

---

## 🎯 Mission Briefing

A port being "open" only tells you half the story. Today's tools answer the real questions: what software, what version, and what operating system is actually behind that open port?

```
🔬 MISSION: Fingerprint Services & Operating Systems
──────────────────────────────────────────
[x] Detect actual service versions with -sV
[x] Attempt OS detection with -O
[x] Run the combined, aggressive -A scan
[x] Learn when OS-guess confidence shouldn't be trusted
──────────────────────────────────────────
STATUS: Networking Day 06 — Done
```

---

## ⚡ Quick Theory

**`-sV` (version detection)** doesn't just trust the port number — it actually sends probes to the port and studies the real response (banners, protocol quirks) to identify the exact software and version running there.

**`-O` (OS detection)** works completely differently: it studies subtle quirks in how a target's TCP/IP stack responds to unusual probes (window sizes, TTL behavior, how it handles malformed packets) and compares that fingerprint against a database of known OS signatures. This is inherently a **guess with a confidence percentage**, never a certainty — and nmap itself explicitly warns when conditions aren't ideal for it.

**A critical limitation worth knowing:** OS fingerprinting works best when nmap can see **both an open AND a closed port** on the target — comparing how each is handled is part of the fingerprint. If every reachable port is either open or filtered (no clean "closed"), nmap warns that results "may be unreliable."

**`-A`** bundles OS detection, version detection, default NSE scripts, and a traceroute into one command — thorough, but noticeably slower and louder than running any of those individually.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🔍 Service/version detection
```bash
$ nmap -sV -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE VERSION
22/tcp  open     ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13 (Ubuntu Linux; protocol 2.0)
80/tcp  open     http    Apache httpd 2.4.7 ((Ubuntu))
443/tcp filtered https
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Nmap done: 1 IP address (1 host up) scanned in 35.19 seconds
```
This is a dramatically different result from Day 04's plain scan, which only showed `ssh` and `http` as guessed labels. Here, `-sV` confirmed the **exact** software and version: OpenSSH 6.6.1p1 on Ubuntu, Apache httpd 2.4.7 on Ubuntu. That's real, actionable fingerprint data — a known version number is exactly what you'd cross-reference against a vulnerability database.

### 🖥️ OS detection on my own machine
```bash
$ sudo nmap -O 127.0.0.1
Not shown: 999 closed tcp ports (reset)
PORT   STATE SERVICE
22/tcp open  ssh
No exact OS matches for host (If you know what OS is running on it, see https://nmap.org/submit/ ).
TCP/IP fingerprint:
OS:SCAN(V=7.99%E=4%D=10/3%OT=22%CT=1%CU=36219%PV=Y%DS=0%DC=L%G=Y%TM=6AC0B55
...
Network Distance: 0 hops

Nmap done: 1 IP address (1 host up) scanned in 11.43 seconds
```
Even on my own, correctly-configured Kali machine, nmap could NOT confidently name the OS — it printed the raw TCP/IP fingerprint instead and suggested submitting it to nmap.org, since my specific kernel version likely isn't in its signature database yet. Network distance of 0 hops confirms this really is the local machine.

### 🧩 Combined aggressive scan (-A)
```bash
$ sudo nmap -A -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE VERSION
22/tcp  open     ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13 (Ubuntu Linux; protocol 2.0)
80/tcp  open     http    Apache httpd 2.4.7 ((Ubuntu))
|_http-server-header: Apache/2.4.7 (Ubuntu)
443/tcp filtered https
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Actiontec MI424WR-GEN3I WAP (96%), DD-WRT v24-sp2 (Linux 2.4.37) (96%),
Linux 3.2 (94%), Linux 4.4 (92%), Microsoft Windows XP SP3 or Windows 7 or Windows Server 2012 (92%),
Microsoft Windows XP SP3 (90%), VMware Player virtual NAT device (90%), BlarC Titan 2100 NAS device (89%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 2 hops
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

TRACEROUTE (using port 80/tcp)
HOP RTT     ADDRESS
1   0.23 ms _gateway (192.168.80.2)
2   0.25 ms scanme.nmap.org (45.33.32.156)

Nmap done: 1 IP address (1 host up) scanned in 202.90 seconds
```
This is the standout result of the day: nmap **explicitly warned** it couldn't find both an open AND a closed port (only open/filtered were available), so the OS guess list is unreliable — and the numbers prove it. The *top-ranked* guess (96%) was a home router (**DD-WRT/Actiontec WAP device**), while the correct answer — a Linux server, confirmed by the SSH/Apache banners in the Service Info line — only scored 92-94%. The raw version/service banners (from `-sV`) were far more trustworthy here than the dedicated OS-guessing engine.

The traceroute also only showed 2 hops total (my own gateway, then straight to scanme.nmap.org) — a surprisingly short path, likely due to how my VM's network/VPN routing is set up, rather than the real internet-wide hop count to that server.

---

## 🧪 What I Actually Found

- [x] `-sV` confirmed exact versions: OpenSSH 6.6.1p1 (Ubuntu), Apache httpd 2.4.7 (Ubuntu)
- [x] `-O` on my own machine: no confident match, raw fingerprint only — my kernel isn't in nmap's signature DB yet
- [x] `-A` OS guess was WRONG at the top of its own confidence list (96% router vs 92-94% Linux, when the real answer was Linux)
- [x] nmap explicitly flagged the condition that caused this: no closed port available to compare against
- [x] Traceroute: only 2 hops from my machine to scanme.nmap.org

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Trust the Banner, Not the Guess**
> In the `-A` scan, the top OS guess (96%) was a home router, but the service banners clearly showed Ubuntu Linux. Which piece of evidence should you actually trust more, and why?

<details>
<summary>My answer</summary>

Trust the service banners (`-sV`'s `OpenSSH ... Ubuntu Linux` and `Apache httpd ... Ubuntu`) over the OS-guess percentages. Banners come from the actual software directly identifying itself in its protocol responses — a much more direct signal. The OS-fingerprint guess is inferred indirectly from TCP/IP stack behavior, and nmap itself warned this specific scan lacked the open+closed port combination it needs to be reliable.

</details>

> **🥊 Challenge 2: Why My Own Machine Wasn't Recognized**
> `-O` on my own, correctly-running Kali machine still came back with "No exact OS matches." Why would this happen on a machine I fully control and know the OS of?

<details>
<summary>My answer</summary>

nmap's OS detection relies on a database of known fingerprints, built from TCP/IP stack behavior that's been seen and catalogued before. A very recent kernel version (newer than what's in nmap's signature database) can behave slightly differently from older, catalogued versions — so even a "textbook" Linux machine can come back unmatched if its specific kernel is new enough that nmap hasn't seen that exact fingerprint yet.

</details>

> **🥊 Challenge 3: When NOT to Use -A**
> `-A` took over 3 minutes for just 3 ports, versus under a minute for `-sV` alone on the same ports. When would you deliberately avoid `-A`?

<details>
<summary>My answer</summary>

Skip `-A` when speed matters more than full detail — a large network sweep across many hosts, a quick "is this even alive and what's open" check, or any situation where a stealthier, less noisy scan is needed. `-A`'s combination of OS detection, version detection, scripts, and traceroute makes it the most informative single command, but also the slowest and most detectable.

</details>

---

## 🧩 Quick Brain Check

1. What's the practical difference between what `-sV` detects and what `-O` detects?
2. Why does OS detection need both an open AND a closed port to be reliable?
3. If the top OS guess has 96% confidence but the service banner clearly says something else, which should you trust?
4. Why might a fully up-to-date, correctly running machine still return "No exact OS matches"?
5. What four things does `-A` combine into a single scan?

---

## 🐛 Errors / Gotchas I Hit

- The `-A` scan's top-ranked OS guess (a home router, 96% confidence) was actually wrong — the real OS (Linux) scored lower in nmap's own list. A strong reminder that OS-detection percentages reflect fingerprint-matching confidence, not ground truth, especially when nmap has already warned the scan conditions aren't ideal.
- `-O` on my own Kali box returned no confident match at all, despite it being a known, correctly-configured machine — a newer kernel simply isn't in nmap's signature database yet.
- The traceroute showed only 2 hops to a server on the public internet, which is unusually short — likely an artifact of how this VM's network/VPN is routed rather than the true internet path.

---

## 🔐 Security Relevance

Version detection is directly actionable for both attackers and defenders: a confirmed `OpenSSH 6.6.1p1` or `Apache 2.4.7` can be checked against known CVEs for that exact version. OS detection is useful for recon but should never be the sole basis for a decision — today's result is a textbook example of why: the highest-confidence guess was simply wrong, and a defender or pentester relying on it alone would have profiled the wrong target entirely.

---

## 🧠 Today's Takeaway

`-sV` reads what a service says about itself — reliable, direct evidence. `-O` infers the OS from indirect network behavior — informative, but explicitly a guess, and one that can rank a wrong answer above the right one when conditions aren't ideal. `-A` combines everything for maximum information at the cost of speed and stealth. The real lesson: cross-check confidence percentages against harder evidence (like service banners) before trusting them.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 07: nmap Part 4 — NSE scripts & saving output**
