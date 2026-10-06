# 🔌 Networking Day 08: netcat Part 1 (Port Testing & Banner Grabbing)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_08%2F15-blue?style=for-the-badge" alt="Day 08"/>
  <img src="https://img.shields.io/badge/tool-netcat-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The nmap arc (Days 04-07) is done. netcat is the stripped-down, general-purpose tool behind a lot of what nmap does under the hood — and today it also becomes a two-way connection, both client and server. 🔌

---

## 🏆 Day 07 Recap — Challenge Solutions

**Challenge 1 (One Failure, Then Success):** A single script failing doesn't invalidate the whole scan — the rest of the run (port states, other scripts) still completed normally.

**Challenge 2 (Why the Comment Header Matters):** It makes results reproducible and verifiable — anyone reviewing the report can see exactly what command produced it and when.

**Challenge 3 (Human vs Machine Output):** XML trades human readability for a consistent, parseable structure that other tools can rely on.

---

## 🎯 Mission Briefing

nmap is built for scanning at scale. netcat is the simpler, more general tool underneath — a raw TCP/UDP connection you fully control, useful for quick port checks, grabbing a service's exact banner, and (as Day 09 will show) listening for connections yourself.

```
🔌 MISSION: Connect Directly, Both Ways
──────────────────────────────────────────
[x] Test if specific ports are open
[x] Grab a real service banner
[x] Start a local listener and connect to it
──────────────────────────────────────────
STATUS: Networking Day 08 — Done
```

---

## ⚡ Quick Theory

**`nc -zv`** tests a port without sending any real data — `-z` means "scan only," `-v` means "tell me what happened." This is the netcat equivalent of nmap's basic port check, just without nmap's extra analysis layered on top.

**Banner grabbing** is simpler than it sounds: many services announce themselves the moment you connect, before you even send anything. SSH does this by design — plain `nc -v <host> 22` is often enough to see the exact version string, no special tooling needed.

**netcat as a listener (`-lvnp`)** flips the tool around — instead of connecting out to something, your own machine becomes the thing being connected to. This is the exact mechanism behind legitimate remote access tools AND malicious reverse shells; the difference is entirely about authorization and intent, not the mechanism itself.

**A raw netcat session has no shell features.** Once connected, you're in a bare TCP pipe — no command history, no arrow-key navigation, none of the conveniences bash normally gives you. Pressing an arrow key doesn't recall a previous command; it just sends the raw escape bytes for that key as literal data.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, two terminals side by side)*

### 🔍 Port testing and banner grabbing (left terminal)
```bash
$ nc -zv scanme.nmap.org 22
scanme.nmap.org [45.33.32.156] 22 (ssh) open

$ nc -v scanme.nmap.org 22
scanme.nmap.org [45.33.32.156] 22 (ssh) open
SSH-2.0-OpenSSH_6.6.1p1 Ubuntu-2ubuntu2.13
```
Port 22 confirmed open, and the banner grab returned the exact same version nmap's `-sV` found back on Day 06 (`OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13`) — netcat got the identical answer with a far simpler tool, since SSH announces its own version string the instant a connection opens.

### 🎧 Starting the listener (left terminal)
```bash
$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [127.0.0.1] from (UNKNOWN) [127.0.0.1] 57070
```

### 🔗 Connecting to it (right terminal)
```bash
$ nc -v 127.0.0.1 4444
localhost [127.0.0.1] 4444 (?) : Connection refused

$ nc -v 127.0.0.1 4444
localhost [127.0.0.1] 4444 (?) open
^[[A
```
The first connection attempt was refused — I tried connecting before the listener in the left terminal had actually started. The second attempt, run after the listener was up, connected successfully (matching the `connect to [127.0.0.1] ... 57070` line that appeared on the left). After connecting, I pressed the up-arrow key expecting command history, and instead got `^[[A` printed literally — a raw netcat session has no line-editing at all, so the arrow key's raw escape sequence just gets sent as plain bytes instead of doing anything useful.

---

## 🧪 What I Actually Found

- [x] Port 22 on `scanme.nmap.org` confirmed open via `-zv`
- [x] Banner grab matched nmap's `-sV` result exactly from Day 06: `OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13`
- [x] First local connection attempt: refused (listener not started yet)
- [x] Second attempt: connected successfully, confirmed on both sides
- [x] Discovered raw netcat sessions don't support arrow-key history (`^[[A` printed literally)
- [ ] Manual HTTP request via `printf | nc` — not captured this round

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Refused, Then Open**
> The exact same command (`nc -v 127.0.0.1 4444`) failed with "Connection refused" the first time and succeeded the second. What changed between the two attempts, and what does "Connection refused" actually mean at the network level?

<details>
<summary>My answer</summary>

Between the two attempts, the listener (`nc -lvnp 4444`) was actually started in the other terminal. "Connection refused" specifically means a SYN packet reached the target machine, but nothing was listening on that port — the OS itself sent back an active rejection (unlike a timeout, which would mean no response at all, often due to a firewall silently dropping the packet).

</details>

> **🥊 Challenge 2: The Mystery Characters**
> `^[[A` appeared in the terminal after pressing the up-arrow key inside an active netcat connection. What actually happened, and why doesn't this happen in a normal bash prompt?

<details>
<summary>My answer</summary>

The up-arrow key doesn't send a single character — it sends an escape sequence (`ESC [ A`, shown as `^[[A`). In a normal bash shell, readline intercepts that sequence and interprets it as "recall previous command." Inside a raw netcat session, there's no readline or shell logic at all — netcat just forwards every byte typed straight into the TCP connection, so the raw escape sequence gets sent (and echoed back) as literal text instead of doing anything special.

</details>

> **🥊 Challenge 3: Same Answer, Simpler Tool**
> The netcat banner grab and nmap's `-sV` scan from Day 06 returned the exact same OpenSSH version string. If the answer is identical, why would anyone bother with nmap's heavier `-sV` instead of just using netcat for everything?

<details>
<summary>My answer</summary>

For one single, known port, netcat is simpler and faster. But nmap's `-sV` scales — it can check hundreds of ports across many hosts in one command, automatically try multiple probe techniques when a service doesn't announce itself immediately, and combine the results with port states, OS detection, and scripts. netcat is the precise, manual tool for one connection at a time; nmap is built for scanning at scale.

</details>

---

## 🧩 Quick Brain Check

1. What does the `-z` flag in `nc -zv` actually prevent from happening?
2. Why did SSH's banner appear automatically, without needing to send anything first?
3. What's the real difference between "Connection refused" and a connection that just hangs/times out?
4. Why doesn't the up-arrow key work the way it does in a normal shell, once inside a raw netcat connection?
5. What's the key difference in purpose between netcat and nmap, even when they can return the same answer?

---

## 🐛 Errors / Gotchas I Hit

- First connection attempt to my own listener was refused — simple timing issue, the listener wasn't started yet in the other terminal when I tried connecting.
- Pressing the up-arrow key inside an active netcat session printed `^[[A` literally instead of recalling a previous command — raw TCP sessions have none of bash's line-editing features.
- Didn't get to the manual HTTP request test (`printf ... | nc`) this round — planned for next time.

---

## 🔐 Security Relevance

The exact mechanism used here — a listener (`-lvnp`) accepting an incoming connection — is the same one behind a reverse shell, one of the most common ways an attacker maintains access after initial compromise. Recognizing an unexpected listening port (`ss -tuln`, from the Linux journal) or an unusual outbound connection is exactly how this gets caught defensively. Banner grabbing is also a direct, lightweight recon technique — no scanner required, just a raw connection and a look at what the service says about itself.

---

## 🧠 Today's Takeaway

netcat strips scanning down to the bare mechanics: a connection, nothing more. `-zv` checks if a port answers, a plain connect often reveals a service's exact version for free, and `-lvnp` turns the tool into a listener — the same basic building block behind both legitimate remote access and malicious reverse shells. And once inside a raw connection, remember: no shell, no history, no arrow keys — just bytes.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 09: netcat Part 2 — listener & simple file transfer**
