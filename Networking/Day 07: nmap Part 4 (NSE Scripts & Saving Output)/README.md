# 📜 Networking Day 07: nmap Part 4 (NSE Scripts & Saving Output)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_07%2F15-blue?style=for-the-badge" alt="Day 07"/>
  <img src="https://img.shields.io/badge/tool-nmap-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The final day of the nmap arc. Days 04-06 found hosts, ports, services and OS hints. Day 07 adds scripted intelligence on top of all of it, and makes the results reusable by saving them properly. 📜

---

## 🏆 Day 06 Recap — Challenge Solutions

**Challenge 1 (Trust the Banner, Not the Guess):** Trust the service banners — they're the software directly identifying itself, far more direct than an inferred OS-fingerprint guess.

**Challenge 2 (Why My Own Machine Wasn't Recognized):** A newer kernel than what's in nmap's signature database can go unmatched, even on a correctly running machine.

**Challenge 3 (When NOT to Use -A):** Skip it when speed or stealth matters more than maximum detail — large sweeps, quick checks, anything where noise is a concern.

---

## 🎯 Mission Briefing

Open ports and version numbers are useful, but NSE (the Nmap Scripting Engine) can go further — grabbing SSH host keys, pulling a web page's title, checking for known misconfigurations, and more. Today also covers making all of this reusable: saving scan results properly instead of letting them vanish from the terminal.

```
📜 MISSION: Script It & Save It
──────────────────────────────────────────
[x] Run the default NSE script set with -sC
[x] Handle a real script execution failure
[x] Save scan output to a readable file
[x] Combine scripts + versions + saved output in one recon scan
──────────────────────────────────────────
STATUS: Networking Day 07 — Done
```

---

## ⚡ Quick Theory

**NSE (Nmap Scripting Engine)** runs extra, purpose-built scripts against open ports to extract more than a bare port/version scan can. `-sC` runs nmap's curated **default, safe** script set automatically — no need to name scripts individually.

**Scripts can fail** — they depend on network conditions, timing, and the exact response from the target at that moment. A failed script doesn't mean the scan itself failed; the rest of the scan still completes, and a re-run often succeeds where the first attempt didn't.

**Saving output (`-oN`, `-oX`, `-oA`)** turns a one-time terminal result into something reusable:
```
-oN   ->  Normal format: identical to terminal output, human-readable, saved to a file
-oX   ->  XML format: structured for OTHER TOOLS to parse programmatically
-oA   ->  ALL formats at once (normal + XML + grepable), using one base filename
```
A saved `-oN` file isn't just a copy-paste of the screen — nmap adds a comment header recording the **exact command and timestamp** used to produce it, which matters for reproducibility (proving later exactly how a result was obtained).

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🧩 NSE basics — including a real script failure
```bash
$ nmap -sC -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE
22/tcp  open     ssh
|_ssh-hostkey: ERROR: Script execution failed (use -d to debug)
80/tcp  open     http
|_http-favicon: Nmap Project
443/tcp filtered https

Nmap done: 1 IP address (1 host up) scanned in 11.11 seconds
```
The `ssh-hostkey` script failed outright on this first attempt — the rest of the scan still completed normally (port states, `http-favicon` still worked fine).

```bash
$ nmap --script "default" -p 22,80,443 scanme.nmap.org
PORT    STATE    SERVICE
22/tcp  open     ssh
| ssh-hostkey:
|   1024 ac:00:a0:1a:82:ff:cc:55:99:dc:67:2b:34:97:6b:75 (DSA)
|   2048 20:3d:2d:44:62:2a:b0:5a:9d:b5:b3:05:14:c2:a6:b2 (RSA)
|   256 96:02:bb:5e:57:54:1c:4e:45:2f:56:4c:4a:24:b2:57 (ECDSA)
|_  256 33:fa:91:0f:e0:e1:7b:1f:6d:05:a2:b0:f1:54:41:56 (ED25519)
80/tcp  open     http
|_http-favicon: Nmap Project
|_http-title: Go ahead and ScanMe!
443/tcp filtered https

Nmap done: 1 IP address (1 host up) scanned in 10.32 seconds
```
Re-running the same script set (explicitly via `--script "default"`, which is what `-sC` is shorthand for) succeeded completely this time — all 4 SSH host key types retrieved, plus a clear web page title. Running `-sC` a third time also succeeded cleanly, confirming the first failure was a one-off transient issue, not a real problem with the scan or target.

Two small details confirm this really is nmap's official test server: the favicon identifies itself as **"Nmap Project"**, and the page title literally reads **"Go ahead and ScanMe!"**

### 💾 Saving output
```bash
$ nmap -sV -p 22,80,443 scanme.nmap.org -oN nmap-scan.txt
PORT    STATE    SERVICE VERSION
22/tcp  open     ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13 (Ubuntu Linux; protocol 2.0)
80/tcp  open     http    Apache httpd 2.4.7 ((Ubuntu))
443/tcp filtered https
Nmap done: 1 IP address (1 host up) scanned in 11.36 seconds

$ ls -lh nmap-scan.txt
-rw-rw-r-- 1 ruin ruin 748 Oct  5 13:21 nmap-scan.txt

$ cat nmap-scan.txt
# Nmap 7.99 scan initiated Mon Oct  5 13:21:44 2026 as: /usr/lib/nmap/nmap --privileged -sV -p 22,80,443 -oN nmap-scan.txt scanme.nmap.org
Nmap scan report for scanme.nmap.org (45.33.32.156)
...
# Nmap done at Mon Oct  5 13:21:56 2026 -- 1 IP address (1 host up) scanned in 11.36 seconds
```
The saved file is a real 748-byte text file, and critically, nmap added a comment line at the top recording the **exact command** that was run and when — this is exactly the kind of detail that matters if these results ever needed to be verified or reproduced later. (I only captured `-oN` this round — `-oX`/`-oA` are still to be tried next time.)

### 🧩 Final combined recon scan
```bash
$ nmap -sC -sV -p 22,80,443 scanme.nmap.org -oN final-recon.txt
PORT    STATE    SERVICE VERSION
22/tcp  open     ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.13 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   1024 ac:00:a0:1a:82:ff:cc:55:99:dc:67:2b:34:97:6b:75 (DSA)
|   2048 20:3d:2d:44:62:2a:b0:5a:9d:b5:b3:05:14:c2:a6:b2 (RSA)
|   256 96:02:bb:5e:57:54:1c:4e:45:2f:56:4c:4a:24:b2:57 (ECDSA)
|_  256 33:fa:91:0f:e0:e1:7b:1f:6d:05:a2:b0:f1:54:41:56 (ED25519)
80/tcp  open     http    Apache httpd 2.4.7 ((Ubuntu))
|_http-favicon: Nmap Project
|_http-title: Go ahead and ScanMe!
|_http-server-header: Apache/2.4.7 (Ubuntu)
443/tcp filtered https
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Nmap done: 1 IP address (1 host up) scanned in 17.62 seconds
```
One command, saved to file, gave: open/filtered port states, exact software versions, 4 SSH host key fingerprints, the web server's favicon identity, page title, HTTP server header, and an OS hint — a genuinely complete first-pass recon picture of a target, all reproducible later from `final-recon.txt`.

---

## 🧪 What I Actually Found

- [x] `-sC` failed once (`ssh-hostkey` script error), succeeded fully on re-run — confirmed transient, not a real problem
- [x] Full SSH host key set retrieved: DSA, RSA, ECDSA, ED25519
- [x] Confirmed via favicon + page title that scanme.nmap.org is genuinely nmap's official test server
- [x] `-oN` output includes a comment header with the exact command + timestamp used
- [x] Combined `-sC -sV -oN` scan produced a complete, saved recon report in one command
- [ ] `-oX` (XML) and `-oA` (all formats) — not captured this round, planned for next time

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: One Failure, Then Success**
> `ssh-hostkey` failed on the first `-sC` run but succeeded on every run after. Does this mean the SCAN itself failed, and should the first result be trusted at all?

<details>
<summary>My answer</summary>

No — the overall scan didn't fail, only one specific script did. The rest of that same run (port states, `http-favicon`) came back fine. A single script failing is a normal, transient occurrence (timing, a dropped packet, a momentary hiccup) and doesn't invalidate the rest of the results from that run. The missing SSH host key info specifically shouldn't be trusted from that first run, but everything else in it was fine.

</details>

> **🥊 Challenge 2: Why the Comment Header Matters**
> The `-oN` file started with a comment line showing the exact command and timestamp used. Why does this matter for a security report, beyond just being "nice to have"?

<details>
<summary>My answer</summary>

It makes the result reproducible and verifiable — anyone reviewing the report later can see exactly what command produced these findings and when, rather than trusting an unlabeled copy-paste. In a real engagement, this kind of audit trail matters for proving how a finding was obtained.

</details>

> **🥊 Challenge 3: Human vs Machine Output**
> `-oN` is described as "human-readable, same as terminal." Why would a tool ever prefer `-oX` (XML) instead, even though it's harder for a person to read directly?

<details>
<summary>My answer</summary>

XML has a consistent, predictable structure that other programs can parse reliably — field names, tags, and nesting stay the same every time. A human-readable text format can vary in layout and is much harder for a script to parse correctly. XML trades human readability for machine reliability, which matters when feeding nmap results into another tool (like a report generator or a vulnerability tracker) automatically.

</details>

---

## 🧩 Quick Brain Check

1. What's the difference between `-sC` and naming a script directly with `--script=<name>`?
2. Why didn't the whole scan fail just because one script (`ssh-hostkey`) failed?
3. What's the practical difference between `-oN` and `-oX`?
4. What extra piece of information does nmap add to a saved `-oN` file beyond the scan results themselves?
5. Name three different pieces of information the final combined recon scan gave you in one command.

---

## 🐛 Errors / Gotchas I Hit

- `ssh-hostkey` failed with "Script execution failed (use -d to debug)" on the very first `-sC` attempt — a transient issue, confirmed by the exact same command succeeding fully on the next two runs. Worth remembering: one failed script isn't a reason to distrust the whole scan.
- Only captured `-oN` output this round — still need to try `-oX` and `-oA` to see the other saved formats.
- No separate `--script=banner` or standalone `--script=http-title` run this time — `http-title` ended up appearing anyway as part of the default script set (`-sC`), which covered that ground.

---

## 🔐 Security Relevance

SSH host key fingerprints (from `ssh-hostkey`) matter for detecting man-in-the-middle attacks — if a server's key fingerprint suddenly changes between scans, that's a red flag worth investigating (the same concept covered back in Day 18-19 of the Linux journey). Saved, timestamped scan output (`-oN`/`-oX`) is also exactly what real penetration test reports are built from — a finding is only as credible as the evidence trail behind it.

---

## 🧠 Today's Takeaway

`-sC` adds scripted intelligence on top of a basic scan — and like any real-world tool, individual scripts can fail without invalidating the whole result. Saving output properly (`-oN` for readability, `-oX` for other tools, `-oA` for both) turns a one-time terminal glance into a reusable, timestamped record. This closes out the nmap arc: discovery (Day 04) → scan types (Day 05) → service/OS detection (Day 06) → scripts and saved output (Day 07).

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 08: netcat Part 1 — port testing & banner grabbing**
