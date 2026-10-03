# ⏱️ Networking Day 05: nmap Part 2 (Scan Types, Timing & Port Ranges)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_05%2F15-blue?style=for-the-badge" alt="Day 05"/>
  <img src="https://img.shields.io/badge/tool-nmap-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 04 found ports. Day 05 is about HOW nmap finds them — different scan types, different speeds, and what you control vs what the network/DNS controls. ⏱️

---

## 🏆 Day 04 Recap — Challenge Solutions

**Challenge 1 (Open vs Filtered):** `open` = something actively responded. `filtered` = no response at all, most likely a firewall silently dropping the probe rather than the port being genuinely closed.

**Challenge 2 (Trusting the Service Name):** No — without `-sV`, service names are a guess from the port number alone, not a confirmed identification.

**Challenge 3 (Why scanme Was Slow):** Not a local problem — scanme.nmap.org deliberately rate-limits heavy scanning since it's a shared public target.

---

## 🎯 Mission Briefing

Not all scans are equal: some complete the full TCP handshake, some don't; some are fast and loud, some are slow and quiet; UDP behaves completely differently from TCP. Today is about understanding those tradeoffs, not just running more scans.

```
⏱️  MISSION: Understand Scan Types & Timing
──────────────────────────────────────────
[x] Compare SYN scan vs Connect scan
[x] Run a UDP scan and see how its results differ
[x] Compare timing templates (T3 default vs T4 aggressive)
[x] Practice port specification: lists, ranges, top-ports
──────────────────────────────────────────
STATUS: Networking Day 05 — Done
```

---

## ⚡ Quick Theory

**SYN scan (`-sS`)** sends the first packet of a TCP handshake (SYN) and, if it gets a reply, immediately sends a RST instead of completing the handshake — "half-open." It needs root privileges to craft raw packets, and is considered stealthier because many basic logging systems only record *completed* connections.

**Connect scan (`-sT`)** completes the full TCP handshake using the OS's normal networking calls. No root required, but it's more "visible" — a completed connection is far more likely to show up in a target's logs.

**UDP scan (`-sU`)** is a different protocol entirely, with no handshake concept at all. Since UDP doesn't reply to confirm anything, nmap often can't tell the difference between "open with a silent service" and "blocked by a firewall" — both show up as `open|filtered`. A `closed` UDP port is actually the most *certain* result, because it means the target sent back an explicit ICMP "port unreachable" message.

**Timing templates (`-T0` to `-T5`)** control how fast nmap sends probes and how long it waits for replies:
```
T0 paranoid   T1 sneaky   T2 polite   T3 normal (default)   T4 aggressive   T5 insane
   slowest, stealthiest ────────────────────────────────▶ fastest, loudest
```
A real attacker trying to avoid detection might deliberately use `-T1` or `-T2` — fewer, slower probes are far less likely to trip an intrusion detection system than a fast, obvious burst of traffic.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### ⚔️ SYN scan vs Connect scan
```bash
$ sudo nmap -sS scanme.nmap.org
Warning: 45.33.32.156 giving up on port because retransmission cap hit (10).
Stats: 0:41:09 elapsed; 0 hosts completed (1 up), 1 undergoing SYN Stealth Scan
SYN Stealth Scan Timing: About 67.67% done; ETC: 13:10 (0:19:39 remaining)
zsh: suspended  sudo nmap -sS scanme.nmap.org
```
After 41 minutes with still ~20 minutes left, I suspended it with Ctrl+Z rather than wait further.

```bash
$ nmap -sT scanme.nmap.org
Stats: 0:00:17 elapsed; 0 hosts completed (1 up), 1 undergoing Connect Scan
Nmap scan report for scanme.nmap.org (45.33.32.156)
Host is up (0.22s latency).
Not shown: 995 filtered tcp ports (no-response)
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
2000/tcp open  cisco-sccp
5060/tcp open  sip
9929/tcp open  nping-echo

Nmap done: 1 IP address (1 host up) scanned in 50.73 seconds
```
`-sT` completed cleanly in under a minute and found all 5 open ports (matching the `9929/nping-echo` discovery from Day 04's `-T4` scan). `-sS` on the same target, same day, was dramatically slower — scanme.nmap.org appears to specifically throttle or deprioritize raw SYN probes more heavily than full-connect ones, which is itself a useful real-world lesson in how a target can respond very differently to different scan types.

### 📡 UDP scan
I scanned my own machine (`127.0.0.1`) instead of scanme.nmap.org for this part, to avoid putting more load on an already rate-limiting public target.
```bash
$ sudo nmap -sU --top-ports 20 127.0.0.1
PORT      STATE  SERVICE
53/udp    closed domain
67/udp    closed dhcps
68/udp    closed dhcpc
69/udp    closed tftp
123/udp   closed ntp
135/udp   closed msrpc
137/udp   closed netbios-ns
138/udp   closed netbios-dgm
139/udp   closed netbios-ssn
161/udp   closed snmp
162/udp   closed snmptrap
445/udp   closed microsoft-ds
500/udp   closed isakmp
514/udp   closed syslog
520/udp   closed route
631/udp   closed ipp
1434/udp  closed ms-sql-m
1900/udp  closed upnp
4500/udp  closed nat-t-ike
49152/udp closed unknown

Nmap done: 1 IP address (1 host up) scanned in 0.17 seconds

$ sudo nmap -sU -p 53,67,68,123,161 127.0.0.1
PORT     STATE  SERVICE
53/udp   closed domain
67/udp   closed dhcps
68/udp   closed dhcpc
123/udp  closed ntp
161/udp  closed snmp

Nmap done: 1 IP address (1 host up) scanned in 0.17 seconds
```
Every single UDP port came back `closed` — meaning my machine actively sent back an ICMP "port unreachable" for each one. This is actually the clearest possible UDP result: no UDP services (DNS server, DHCP server, SNMP agent, etc.) are running locally, so there's nothing to respond and the OS correctly reports each port as closed rather than the more ambiguous `open|filtered`.

### ⏱️ Timing comparison
```bash
$ time nmap -T3 -p 22,80,443 scanme.nmap.org
Failed to resolve "scanme.nmap.org".
WARNING: No targets were specified, so 0 hosts scanned.
real    15.43s
user    0.04s
sys     0.00s

$ time nmap -T4 -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE
22/tcp  open     ssh
80/tcp  open     http
443/tcp filtered https

real    2.06s
user    0.03s
sys     0.02s
```
The `-T3` run failed to resolve the hostname at all — a DNS hiccup, not a real timing result — so the ~15 second "real" time there was mostly my resolver timing out, not nmap scanning anything. This wasn't a fair T3-vs-T4 comparison because of that failure; the only valid data point here is that `-T4` completed a clean 3-port scan in 2.06 seconds once DNS actually worked.

### 🎯 Port specification
```bash
$ nmap -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE
22/tcp  open     ssh
80/tcp  open     http
443/tcp filtered https

Nmap done: 1 IP address (1 host up) scanned in 1.91 seconds

$ nmap -p 20-25 scanme.nmap.org
PORT   STATE    SERVICE
20/tcp filtered ftp-data
21/tcp filtered ftp
22/tcp open     ssh
23/tcp filtered telnet
24/tcp filtered priv-mail
25/tcp filtered smtp

Nmap done: 1 IP address (1 host up) scanned in 1.89 seconds
```
Scanning the 20-25 range specifically showed that only port 22 is genuinely open — every other port in that range (including FTP, Telnet, and SMTP, all older/less secure protocols) came back `filtered`. That's a reasonable, security-conscious configuration: legacy ports blocked, only SSH exposed.

---

## 🧪 What I Actually Found

- [x] `-sT` completed in ~50s with 5 open ports; `-sS` was so slow on the same target that I suspended it after 41+ minutes
- [x] UDP scan of my own machine: all tested ports `closed` (no local UDP services running)
- [x] `-T4` scan: 2.06 seconds for 3 ports; `-T3` run failed due to a DNS resolution issue, not a genuine slower timing result
- [x] Port range 20-25 on scanme.nmap.org: only 22 (SSH) open, everything else filtered

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Suspended Scan**
> `sudo nmap -sS scanme.nmap.org` was suspended with Ctrl+Z after running 41+ minutes. Is the process actually stopped now, or still doing something in the background?

<details>
<summary>My answer</summary>

Ctrl+Z only **suspends** a job, it doesn't kill it — the process is paused but still exists (zsh literally printed "suspended"). It can be checked with `jobs`, resumed with `fg`, or properly terminated with `kill %1` (or `kill <PID>`). If I just closed the terminal without doing one of those, depending on the shell it might still linger as a background process.

</details>

> **🥊 Challenge 2: A Fair Comparison**
> The T3 vs T4 timing test wasn't really fair because of what happened. What should be done differently to get a genuine timing comparison next time?

<details>
<summary>My answer</summary>

The T3 run failed at DNS resolution before nmap even started scanning, so its 15.43s "real" time reflects a resolver timeout, not scan speed. For a fair comparison, I should either resolve the IP once beforehand and scan the IP directly (removing DNS as a variable), or simply re-run T3 and confirm it resolves successfully before trusting the timing numbers.

</details>

> **🥊 Challenge 3: The Cleanest UDP Result**
> All my local UDP scan results came back `closed`, not `open|filtered`. Why is `closed` actually the MOST trustworthy UDP result, compared to `open|filtered`?

<details>
<summary>My answer</summary>

A `closed` UDP result means the target actively replied with an ICMP "port unreachable" message — a definite, confirmed answer. `open|filtered` means nmap got NO response at all, which could mean the port is genuinely open with a service that just doesn't reply to an empty probe, or it could mean a firewall silently dropped the packet — nmap can't distinguish between those two cases, so `closed` is actually the more certain, informative result.

</details>

---

## 🧩 Quick Brain Check

1. Why does `-sS` require root privileges but `-sT` doesn't?
2. Why might a target server respond very differently to a SYN scan than to a Connect scan?
3. What does a UDP `open|filtered` result actually mean, and why is it ambiguous?
4. What's the practical risk of trusting a `time` measurement from a scan that failed partway through?
5. Why would a real attacker sometimes deliberately choose `-T1` over `-T4`?

---

## 🐛 Errors / Gotchas I Hit

- `sudo nmap -sS scanme.nmap.org` ran for 41+ minutes without finishing and I had to suspend it (Ctrl+Z) — the suspended job isn't actually killed, just paused; worth remembering to `kill` it properly rather than leaving it dangling.
- `time nmap -T3 ...` failed with "Failed to resolve scanme.nmap.org" — a DNS hiccup at that exact moment, not a real finding about T3's speed. Important not to draw conclusions from a run that didn't actually complete its job.
- The UDP scan was run against `127.0.0.1` instead of `scanme.nmap.org` as originally planned, specifically to avoid adding more load to a target that was already showing signs of rate-limiting earlier in the lab.

---

## 🔐 Security Relevance

The difference in how scanme.nmap.org responded to `-sS` (very slow/throttled) versus `-sT` (fast, completed normally) is a live example of how real-world targets can have different detection or rate-limiting behavior for different scan types — exactly the kind of signal a penetration tester watches for, and exactly the kind of defense a blue team would want to tune (e.g., an IDS specifically flagging raw SYN floods more aggressively than completed connections).

---

## 🧠 Today's Takeaway

`-sS` and `-sT` can get the same answer but behave very differently against a real target — speed, root requirements, and how "visible" they are can all vary. UDP's `closed` is more trustworthy than its `open|filtered`. And a timing comparison is only meaningful if both runs actually completed — a DNS failure isn't a timing result, it's just noise.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 06: nmap Part 3 — service & OS detection**
