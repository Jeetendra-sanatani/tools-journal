# 🚫 Sysadmin Day 06: fail2ban (Auto-Blocking Brute-Force Attempts)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_06-blue?style=for-the-badge" alt="Day 06"/>
  <img src="https://img.shields.io/badge/tool-fail2ban-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The lab promised a ban on myself within a few minutes. What actually happened: three failed logins, zero bans, and a `0` from the unban command. A test that "fails" like this is worth more than one that works first try, because it shows exactly where the tool's safety rules sit. 🔐

---

## 🏆 Day 05 Recap — iptables Chains, Logging and Saved Rules

Day 05 showed that `ufw` and Docker already own the real `INPUT`/`FORWARD` chains on this machine, that `LOG` only records and never blocks by itself, and that a saved ruleset can be validated safely with `iptables-restore --test`. Today's tool, `fail2ban`, works on top of exactly that knowledge: when it decides to block an IP, the block is just one more `iptables` chain.

---

## 🎯 Mission Briefing

Four things were planned: read the defaults, enable the `sshd` jail, trigger a real ban on myself, and unban myself. The first two went as planned. The last two ran, but no ban ever happened, so there was nothing to unban.

```
🚫 MISSION: Automate the Brute-Force Investigation
──────────────────────────────────────────
[x] Check the starting state and read the default numbers
[x] Enable the sshd jail through jail.local
[~] Trigger a real ban: 3 failed logins sent, but NO ban happened
[~] Unban myself: command ran, returned 0 (nothing to unban)
──────────────────────────────────────────
STATUS: Sysadmin Day 06 — Done, with an honest "ban never triggered" result
```

---

## ⚡ Quick Theory

**fail2ban is the Linux journal Day 28 investigation, automated.** Instead of manually running `grep "Failed password" | sort | uniq -c`, fail2ban watches a log source, counts failures per IP, and acts when a threshold is crossed.

**Three numbers define a jail.** `maxretry` failures within `findtime` get an IP banned for `bantime`. With the defaults seen today (`maxretry = 5`, `findtime = 10m`, `bantime = 10m`): 5 failures within 10 minutes means a 10-minute ban.

**Never edit `jail.conf`.** It is overwritten on updates. Custom settings go in `jail.local`, which fail2ban reads on top of `jail.conf` and merges.

**A ban is a real `iptables` rule.** fail2ban inserts its own chain (`f2b-<jail>`) automatically, the same kind of chain-and-rule structure from Day 04 and 05.

**fail2ban reads the journal, not just log files.** The jail status line `Journal matches: _SYSTEMD_UNIT=ssh.service + _COMM=sshd` shows it pulling SSH events straight from the systemd journal.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working from `~/Desktop/github`)*

### 📋 Step 0 + Part A — Starting state and the default numbers
```bash
$ sudo apt install fail2ban -y
fail2ban is already the newest version (1.1.1-1).
...
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354

$ sudo fail2ban-client status
2026-10-21 15:53:42,645 fail2ban  [271064]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?
```
fail2ban was already installed, but the service wasn't running, so the client couldn't find its socket. That error is the first lesson of the day: installing a service is not the same as running it.

```bash
$ grep -E '^(bantime|findtime|maxretry)' /etc/fail2ban/jail.conf | head -5
bantime  = 10m
findtime = 10m
maxretry = 5
bantime  = 48h
maxretry = 1
```
The first three lines are the global defaults every jail inherits: **ban for 10 minutes, count failures over a 10-minute window, ban after 5 failures.** The last two (`48h`, `1`) are not defaults. `head -5` simply kept reading further down the file and caught a different jail's own override. A plain `grep | head` can't tell global defaults from per-jail overrides.

### ⚙️ Part B — Enabling the sshd jail
```bash
$ sudo fail2ban-client status sshd
2026-10-21 15:55:08,754 fail2ban  [272500]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?

$ sudo nano /etc/fail2ban/jail.local
$ sudo systemctl restart fail2ban

$ cat /etc/fail2ban/jail.local
[sshd]
enabled = true
```
Same socket error again, because the service still wasn't running. After creating `jail.local` and running `systemctl restart fail2ban`, the jail came up.

One detail matters later: this `jail.local` contains **only `enabled = true`**. The lab's `maxretry = 3`, `findtime = 300` and `bantime = 600` lines were not in the file, so the defaults (`5` / `10m` / `10m`) were the ones actually in force.

### 🔨 Part C — Trying to trigger a ban
```bash
$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
Jail active, clean slate: 0 failed, 0 banned.

```bash
$ ssh fakeuser@127.0.0.1
fakeuser@127.0.0.1's password:
Permission denied, please try again.
fakeuser@127.0.0.1's password:
Permission denied, please try again.
fakeuser@127.0.0.1's password:
fakeuser@127.0.0.1: Permission denied (publickey,password).

$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
I used a made-up user (`fakeuser`) instead of my real account, a deliberately safer choice for a test that is meant to get something blocked. Three wrong passwords were sent, SSH rejected all three, and then fail2ban's counters **did not move at all**: still 0 failed, 0 banned.

There are two separate things to explain here:

1. **Why no ban:** the jail was running on the default `maxretry = 5`, and only 3 attempts were made. Even if all 3 had been counted, 3 is below 5.
2. **Why not even `Total failed: 3`:** this is the more interesting part. A counted failure would have shown up in `Total failed` regardless of the ban threshold. The most likely explanation is that fail2ban's default `ignoreip` setting exempts localhost (`127.0.0.1`), so failures from my own loopback address are skipped before they are ever counted. This is a safety feature that stops a sysadmin from banning themselves, and it also means a `127.0.0.1` test against a default config can't work. *(This is the likely cause, not yet verified. The checks are listed under "Errors / Gotchas" below.)*

### 🔓 Part D — Unbanning
```bash
$ sudo fail2ban-client set sshd unbanip 127.0.0.1
0

$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
The `0` returned by `unbanip` means nothing was unbanned, which is consistent with the status output: the banned list was already empty. The command itself works; it just had nothing to act on.

Three lab checks could not be captured because no ban existed: the `f2b-sshd` chain in `iptables`, the ban line in `/var/log/fail2ban.log`, and the "is the iptables rule gone after unban" check.

---

## 🧪 What I Actually Found

- [x] fail2ban was installed but **not running**; `fail2ban-client` failed with a socket error until `systemctl restart fail2ban`
- [x] Real defaults on this machine: `maxretry = 5`, `findtime = 10m`, `bantime = 10m`
- [x] `grep | head -5` on `jail.conf` mixed global defaults with another jail's override (`48h`, `maxretry = 1`)
- [x] The `sshd` jail reads from the systemd journal (`_SYSTEMD_UNIT=ssh.service + _COMM=sshd`), not only from log files
- [x] My `jail.local` had only `enabled = true`, so the lab's `maxretry = 3` was never applied
- [x] 3 failed SSH logins to `127.0.0.1` produced **0 failed, 0 banned** in the jail status
- [x] `unbanip` returned `0` because there was no ban to remove
- [ ] fail2ban's `f2b-sshd` iptables chain, the ban line in `fail2ban.log`, and a real ban/unban cycle: not captured, since no ban happened

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Three Failures, Zero Counted**
> After 3 wrong passwords, the jail still showed `Total failed: 0`. The ban threshold alone can't explain that. What can?

<details>
<summary>My answer</summary>

The threshold (`maxretry`) only decides when a ban happens; it has nothing to do with whether a failure is counted in the first place. `Total failed: 0` means fail2ban never recorded the three failures at all. The most likely reason is `ignoreip`: fail2ban's defaults exempt `127.0.0.1`, so failures coming from my own machine's loopback address are dropped before counting. A second possibility is simple timing (fail2ban polls the journal with a small delay), which is why the next step is to check `fail2ban-client get sshd ignoreip` and the fail2ban log, not to assume.

</details>

> **🥊 Challenge 2: What the Default Numbers Say**
> With `maxretry = 5`, `findtime = 10m`, `bantime = 10m`, describe in one sentence the rule they form, and say whether my 3 attempts could ever have triggered it.

<details>
<summary>My answer</summary>

The rule is: "if one IP fails 5 times within 10 minutes, block it for 10 minutes." My 3 attempts could not have triggered it even if every one had been counted, because 3 is under the limit of 5. The lab's `maxretry = 3` would have, but those lines never made it into my `jail.local`.

</details>

> **🥊 Challenge 3: The Lonely `0`**
> `unbanip 127.0.0.1` printed `0`. Is that an error? What does it tell me?

<details>
<summary>My answer</summary>

It is not an error. The number is how many addresses were actually unbanned, so `0` means the command ran correctly but found no ban on that IP to remove. That matches the status output right before it, where the banned IP list was empty. It's also a handy check: if `unbanip` returns `1` on a real ban, the removal worked.

</details>

---

## 🧩 Quick Brain Check

1. Why did `fail2ban-client status` fail with a socket error right after installation?
2. What do `maxretry`, `findtime` and `bantime` mean together in one sentence?
3. Why must custom settings go in `jail.local` and not `jail.conf`?
4. Why could `Total failed` stay at 0 even after 3 wrong SSH passwords?
5. What does `unbanip` returning `0` mean?

---

## 🐛 Errors / Gotchas I Hit

- **Socket error on `fail2ban-client status`:** the service wasn't running. `systemctl restart fail2ban` fixed it (`systemctl enable --now fail2ban` would also make it start on every boot).
- **`jail.local` was incomplete:** only `enabled = true` was saved. The `maxretry`, `findtime` and `bantime` lines from the lab were missing, so the defaults applied and the test threshold was 5, not 3.
- **No ban was triggered:** counters stayed at 0 after 3 failed logins. The likely cause is localhost being on fail2ban's ignore list. To confirm, run `sudo fail2ban-client get sshd ignoreip`, `grep -n ignoreip /etc/fail2ban/jail.conf`, and `sudo grep -i ignore /var/log/fail2ban.log`.
- **Missing proof:** the `f2b-sshd` chain, the ban line in `fail2ban.log` and the post-unban iptables check couldn't be captured without a real ban. A retry with the full `jail.local` and localhost removed from the ignore list would fill those in.

---

## 🔐 Security Relevance

fail2ban turns a manual log investigation into automatic defense, but today showed its safety-first design: it refuses by default to ban localhost, so a misconfigured test can't lock an admin out of their own machine. That's the right default for real servers, where the same `ignoreip` list is usually where a trusted office IP or management host gets added. For attackers, it's a reminder that unlimited password guessing against SSH is exactly what this tool exists to cut off after a handful of tries.

---

## 🧠 Today's Takeaway

A tool that "didn't work" can teach more than one that does. fail2ban was installed but not running, my `jail.local` was missing the three tuning lines, and even with 3 real failed logins the counters stayed at zero, most likely because localhost is protected by default. The mechanics are clear (`maxretry` failures within `findtime` means a `bantime` ban, enforced through an `iptables` chain), and the real ban/unban cycle is the one piece still to capture.

---

⬅️ [Back to Sysadmin index](/Sysadmin) | ➡️ Next up: **Day 07: logrotate — log rotation & retention**
