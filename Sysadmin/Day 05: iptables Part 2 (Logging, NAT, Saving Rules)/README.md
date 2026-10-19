# 🔐 Sysadmin Day 05: iptables Part 2 (Logging, NAT, Saving Rules)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_05-blue?style=for-the-badge" alt="Day 05"/>
  <img src="https://img.shields.io/badge/tool-iptables-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 04 found a machine with real ufw and Docker rules already running. Today's lab was written for a clean test VM — so the more valuable thing wasn't following it literally, it was adapting it safely for a machine with live rules actually worth protecting. 🔐

---

## 🏆 Day 04 Recap — ufw and Docker Own the Real Chains

`iptables -L` on this machine never shows plain ACCEPT/DROP rules directly in `INPUT` — every rule is a jump into a `ufw-*` chain, and Docker adds 6 more chains into `FORWARD` for container networking. The `nat` table already had live `MASQUERADE` and `DNAT` rules from Docker's own port-publishing, a preview of today's NAT topic, already running before any manual rule was added.

---

## 🎯 Mission Briefing

Four things were planned: logging, NAT, save/restore, and a base firewall script. All four happened, but two of them were deliberately adapted once it became clear this isn't a disposable lab VM — it's a machine with Docker containers and a working `ufw` setup actually depending on its current rules.

```
🔐 MISSION: Logging, NAT, Persistence, Base Policy
──────────────────────────────────────────
[x] Log traffic with LOG, confirm it doesn't block anything by itself
[x] Read the real NAT table from a second angle (-S instead of -L -v -n)
[~] Save rules AND validate a restore, safely, WITHOUT an actual flush+restore cycle
[~] Check the "base firewall" status: found ufw already provides it, didn't build a new one on top
──────────────────────────────────────────
STATUS: Sysadmin Day 05 — Done, adapted sensibly for a live system
```

---

## ⚡ Quick Theory

**`LOG` really is just a logger.** It writes a kernel log line and lets the packet continue to whatever rule comes next in the chain — if nothing after it blocks the traffic, the traffic goes through completely normally, logged but untouched.

**Loopback traffic is seen twice by `INPUT`.** A ping to `127.0.0.1` isn't one packet — the echo request travels out over `lo` and back in as "input," and the echo reply the kernel generates does the same thing in the other direction. Anything matching ICMP on `lo` in the `INPUT` chain sees both halves of every round trip, so a counter can show twice the number of pings sent.

**There's a 4th table beyond `filter`/`nat`/`mangle`: `raw`.** It's checked before connection tracking even happens, and it's where Docker adds rules that silently `DROP` anyone trying to reach a container's IP directly from outside its own bridge interface — a defense that only makes published ports reachable, not every port on every container.

**`iptables-restore --test` validates without touching anything live.** It parses a saved rules file and reports whether it WOULD apply cleanly, without actually loading it. On a machine where the current rules are genuinely doing work (unlike a disposable test rule), that's a much safer way to confirm a backup is good than actually flushing and reloading.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, continuing in `/usr/share/wordlists`)*

### 📝 Logging — proving LOG alone doesn't block
```bash
$ sudo iptables -I INPUT 1 -i lo -p icmp -j LOG --log-prefix "LAB-ICMP: " --log-level 4

$ ping -c 4 127.0.0.1
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.109 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.055 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.053 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.050 ms
--- 127.0.0.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3053ms
```
No `DROP` rule was added this time — on purpose. This isolates exactly what `LOG` does on its own: all 4 pings got through with 0% loss, while still being recorded.

```bash
$ sudo journalctl -k --since "5 minutes ago" | grep "LAB-ICMP"
Oct 17 13:35:11 Devil kernel: LAB-ICMP: IN=lo OUT= ... SRC=127.0.0.1 DST=127.0.0.1 ... PROTO=ICMP ... ID=29452 SEQ=1
Oct 17 13:35:11 Devil kernel: LAB-ICMP: IN=lo OUT= ... SRC=127.0.0.1 DST=127.0.0.1 ... PROTO=ICMP ... ID=29452 SEQ=1
Oct 17 13:35:12 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=2
Oct 17 13:35:12 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=2
Oct 17 13:35:13 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=3
Oct 17 13:35:13 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=3
Oct 17 13:35:14 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=4
Oct 17 13:35:14 Devil kernel: LAB-ICMP: IN=lo OUT= ... ID=29452 SEQ=4

$ sudo dmesg | grep "LAB-ICMP" | tail -10
(the same 8 lines, confirming journalctl -k and dmesg surface the exact same kernel log entries)

$ sudo iptables -L INPUT -n -v --line-numbers
num pkts bytes target in out source destination
1      8   672 LOG    icmp -- lo * 0.0.0.0/0 0.0.0.0/0  LOG flags 0 level 4 prefix "LAB-ICMP: "
2   1334  459K ufw-before-logging-input ...
```
8 log lines, not 4 — matching the `8 672` packet counter on the rule exactly. This is the loopback double-count from the theory above: each of the 4 pings produces one echo request AND one echo reply, and both legs cross `lo` and get caught by the same `INPUT` rule, so 4 pings become 8 logged packets.

```bash
$ sudo iptables -D INPUT -i lo -p icmp -j LOG --log-prefix "LAB-ICMP: " --log-level 4
$ sudo iptables -L INPUT -n -v --line-numbers
num pkts bytes target
1   1341  459K ufw-before-logging-input ...
```
Clean removal, back to the exact same `ufw-before-logging-input` as rule 1.

### 🌐 NAT — read from a different angle, nothing new applied
```bash
$ sudo iptables -t nat -S
-P PREROUTING ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-N DOCKER
-A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
-A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A POSTROUTING -s 172.18.0.0/16 ! -o br-81243d49950f -j MASQUERADE
-A DOCKER -i docker0 -j RETURN
-A DOCKER -i br-81243d49950f -j RETURN
-A DOCKER -d 127.0.0.1/32 ! -i br-81243d49950f -p tcp -m tcp --dport 4222 -j DNAT --to-destination 172.18.0.2:4222
-A DOCKER ! -i br-81243d49950f -p tcp -m tcp --dport 3000 -j DNAT --to-destination 172.18.0.3:3000
-A DOCKER ! -i br-81243d49950f -p tcp -m tcp --dport 9458 -j DNAT --to-destination 172.18.0.3:9458
-A DOCKER -d 127.0.0.1/32 ! -i br-81243d49950f -p tcp -m tcp --dport 27017 -j DNAT --to-destination 172.18.0.4:27017
```
Same real Docker NAT setup confirmed again from Day 04, this time in `-S` format — the exact commands that would recreate every rule, rather than the table layout `-L -v -n` gives. The test `MASQUERADE` rule the lab offered as optional wasn't added, since there's nothing behind this machine to actually route for — reading the real rules already made the point.

### 💾 Save and restore — adapted for a live system
```bash
$ sudo iptables-save > ~/iptables-backup.rules
$ ls -lh ~/iptables-backup.rules
-rw-r--r-- 1 ruin ruin 7.6K Oct 17 13:38 /home/ruin/iptables-backup.rules

$ cat ~/iptables-backup.rules
# Generated by iptables-save v1.8.13 (nf_tables) on Sat Oct 17 13:38:59 2026
*raw
:PREROUTING ACCEPT [1565:613371]
:OUTPUT ACCEPT [0:0]
-A PREROUTING -d 172.18.0.2/32 ! -i br-81243d49950f -j DROP
-A PREROUTING -d 172.18.0.3/32 ! -i br-81243d49950f -j DROP
-A PREROUTING -d 172.18.0.4/32 ! -i br-81243d49950f -j DROP
-A PREROUTING -d 127.0.0.1/32 -i lo -p tcp -m tcp --dport 4222 -j DROP
-A PREROUTING -d 127.0.0.1/32 -i lo -p tcp -m tcp --dport 27017 -j DROP
COMMIT
*filter
:INPUT DROP [806:47196]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [14:560]
... (DOCKER*, ufw-* chain definitions, then their rules, then *nat matching what -S showed above)
COMMIT
```
A real 7.6K backup, containing not just `filter`/`nat` but a `*raw` table too — one I hadn't accounted for in Day 04's theory. Docker uses it specifically to `DROP` any direct attempt to reach a container's own IP (`172.18.0.2/32`, `.3/32`, `.4/32`) from outside its own bridge interface, and to block direct loopback access to two of the published ports (`4222`, `27017`) except through the proper published path. `raw` runs before connection tracking even starts — it's the earliest point a packet can be judged.

```bash
$ sudo iptables-restore --test < ~/iptables-backup.rules
```
(no output — `--test` stayed silent, which means the file parsed and would apply cleanly)

Rather than the lab's suggested `-F` (flush everything) followed by a real restore, this used `--test`, which checks that the saved file is valid and loadable WITHOUT actually touching the live ruleset. On a machine where `ufw` and Docker's rules are genuinely doing active work right now, that's a deliberately safer way to prove the backup is good — no window where the real firewall is briefly gone.

### 🧱 Base firewall — found it already exists
```bash
$ echo "═══ BASE FIREWALL STATUS ═══"
sudo iptables -L INPUT -n -v
sudo iptables -L OUTPUT -n -v
sudo iptables -L FORWARD -n -v
═══ BASE FIREWALL STATUS ═══
Chain INPUT (policy DROP 818 packets, 47796 bytes)
 1391  462K ufw-before-logging-input ...
 ... (the same ufw-* jump chain seen throughout)

Chain OUTPUT (policy ACCEPT 14 packets, 560 bytes)
 ... (ufw-before-output and friends)

Chain FORWARD (policy DROP 0 packets, 0 bytes)
  199  152K DOCKER-USER ...
  199  152K DOCKER-FORWARD ...
  ... (ufw-*-forward chains)
```
This is a status check of the CURRENT rules, not the lab's script actually applied — no new `-A INPUT -i lo -j ACCEPT` / `ESTABLISHED,RELATED` / `--dport 22` rules were added on top. What it shows instead is worth noting on its own: `INPUT`'s policy is already `DROP`, `FORWARD`'s is already `DROP`, `OUTPUT`'s is already `ACCEPT` — exactly the policy shape Part D's script was about to build from scratch. `ufw` is already running a default-deny firewall with its own allow-list underneath (`ufw-user-input` has the equivalent of the SSH and established-connection rules the lab script would have added). Building a second, parallel base firewall on top of an already-active one risked conflicting with it rather than adding anything new.

---

## 🧪 What I Actually Found

- [x] `LOG` alone, with no `DROP` after it, let all 4 pings through at 0% loss while still recording every one
- [x] The LOG rule's counter (`8 672`) was exactly double the ping count — both the request and reply legs of loopback ICMP hit the same `INPUT` rule
- [x] `journalctl -k` and `dmesg` surfaced the identical 8 kernel log lines, confirming they're reading the same underlying log
- [x] Re-confirmed the real Docker `nat` rules via `-S`, and chose not to add an unnecessary test rule
- [x] Discovered a 4th table, `raw`, where Docker drops direct access to container IPs and two published ports except through their proper path
- [x] Saved a real 7.6K rules backup and validated it with `iptables-restore --test`, deliberately skipping an actual flush+restore cycle on a system with live rules
- [x] Confirmed `ufw` already implements the default-DROP-plus-allow-list pattern Part D's script was going to build — chose not to layer a second one on top
- [ ] Lab's literal Part D script (`-A INPUT -i lo -j ACCEPT`, `ESTABLISHED,RELATED`, `--dport 22`) as NEW rules: not run, since the equivalent already exists via `ufw`

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Eight, Not Four**
> The LOG rule's packet counter read `8 672` after exactly 4 pings. Walk through why the number is doubled, step by step.

<details>
<summary>My answer</summary>

Every `ping` to `127.0.0.1` has two legs, and both travel over the loopback interface: the echo request going "out" and the echo reply coming back "in" are both, from the kernel's point of view, packets arriving on `lo`. A rule matching ICMP on `-i lo` in the `INPUT` chain sees both legs of every round trip, so 4 pings (4 requests + 4 replies) become 8 matched packets, which is exactly what the counter showed.

</details>

> **🥊 Challenge 2: Backup Confirmed, Nothing Touched**
> `iptables-restore --test` was used instead of an actual flush-then-restore. What does `--test` actually confirm, and what does it NOT confirm, compared to a real restore?

<details>
<summary>My answer</summary>

`--test` confirms the file is syntactically valid and that every rule in it refers to something that currently exists (chains, tables, matches) — in other words, that loading it WOULD succeed without errors. What it doesn't confirm is the actual runtime effect of applying it: whether traffic genuinely gets blocked or allowed as expected once the rules are live, and whether anything (like an existing connection) breaks during the moment of swapping rulesets. For a disposable test rule, a real flush+restore proves more; for a backup of a live system's rules, `--test` is the safer way to get most of that confidence without the risk.

</details>

> **🥊 Challenge 3: Building a Second Firewall on Top of the First**
> The "base firewall status" check showed `ufw` already enforces default-DROP with an allow-list. What could have gone wrong if the lab's exact Part D script had been run anyway, adding a second set of loopback/established/SSH rules on top?

<details>
<summary>My answer</summary>

Nothing would necessarily break immediately, since both rule sets would mostly agree (allow loopback, allow established, allow SSH) — but it would leave two independent sources of truth managing overlapping decisions. If `ufw` were later changed through its own commands (`ufw allow`, `ufw deny`), the manually added rules sitting elsewhere in the chain wouldn't be touched by those commands, creating a setup where `ufw status` no longer reflects everything actually happening in `INPUT`. That's a maintenance trap: a future audit relying on `ufw`'s own view of things would miss rules that exist outside its management.

</details>

---

## 🧩 Quick Brain Check

1. Why did the LOG rule's packet count come out to exactly double the number of pings sent?
2. What's the practical difference between `iptables-restore --test` and an actual `iptables-restore`?
3. What is the `raw` table used for, and when does it run relative to `filter`?
4. Why would building a brand-new base-firewall script on a machine where `ufw` is already enforcing a similar policy be worth reconsidering?
5. What two places (one log source, one command) confirmed the exact same LOG entries today?

---

## 🐛 Errors / Gotchas I Hit

- No DROP rule was added alongside LOG this time, which turned out to be a cleaner test of LOG's actual behavior (pure logging, zero traffic impact) than the lab's original LOG+DROP combination would have shown.
- The "base firewall" script wasn't actually applied as new rules — checking first revealed `ufw` already implements the same pattern, and adding a parallel, independently-managed rule set on top was judged not worth the maintenance risk.
- The save/restore test used `--test` instead of a real flush+restore cycle, specifically because this machine's current rules (`ufw` + Docker) are live and doing real work, unlike a disposable rules file on a throwaway VM.

---

## 🔐 Security Relevance

A disposable test rule flush is harmless on a clean lab machine, but the same action on a system with live container networking and an active firewall policy could briefly drop real protections — exactly the kind of judgment call a working sysadmin makes constantly: is this environment safe to experiment on directly, or does it need a non-destructive check first? The `raw` table's container-isolation rules are also a good defensive pattern worth remembering: publishing a port deliberately (via Docker's `-p`) is different from a container's IP being reachable on every other port by accident, and `raw`-table `DROP` rules are how that gap gets closed.

---

## 🧠 Today's Takeaway

`LOG` genuinely does nothing but log — proven cleanly by watching 4 pings sail through at 0% loss while still showing up, doubled, in the kernel log. A real system's current state is worth checking before applying a script written for a clean one: `ufw` was already doing most of what Day 05's "base firewall" intended to build from scratch, and the `raw` table turned out to be a whole extra layer neither Day 04 nor today's theory had planned for ahead of time.

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 06: fail2ban — auto-blocking brute-force attempts**
