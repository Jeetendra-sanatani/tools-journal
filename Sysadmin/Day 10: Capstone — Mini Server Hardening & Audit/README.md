# 🏁 Sysadmin Day 10: Capstone — Mini Server Hardening & Audit

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_10-blue?style=for-the-badge" alt="Day 10"/>
  <img src="https://img.shields.io/badge/type-capstone-purple?style=for-the-badge" alt="Capstone"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> No new tool today. Ten days of tools get pointed at one machine to answer the sysadmin's real question: **what is this machine, what defends it, who's watching it, and is it kept tidy?** The most useful answer turned out to be one I didn't expect: a defense that was switched off. 🏁

---

## 🏆 Day 09 Recap — ncdu

Day 09 showed where the disk space goes (`/var/log` was 364.6 MiB, almost all of it the journal) and how a deleted file can stay on disk while a process holds it open. Today's housekeeping and log-rotation steps build directly on that.

---

## 🎯 Mission Briefing

```
🏁 MISSION: Audit My Own Machine
──────────────────────────────────────────
[x] Take an inventory of the machine (hostnamectl, lscpu)
[x] Check the brute-force defense (fail2ban) → found it NOT running
[x] Put an audit watch on a security config file (auditd on sshd_config)
[x] Housekeeping: apt autoremove and apt clean
[x] Rotate a log with copytruncate from a root-owned config
──────────────────────────────────────────
STATUS: Sysadmin Day 10 — Done, with one defense found down
```

---

## ⚡ Quick Theory

A sysadmin's loop is five questions, and each one maps to a tool from this phase:

| Question | Tool | From |
| --- | --- | --- |
| What is this machine? | `hostnamectl`, `lscpu`, `free` | — |
| What's exposed? | `ss`, `lsof` | Day 02 |
| What blocks it? | `ufw` / `iptables` (read only) | Days 04-05 |
| What stops brute force? | `fail2ban` | Day 06 |
| Who's watching changes? | `auditd` | Day 08 |
| Will logs and disk stay healthy? | `logrotate`, `ncdu`, `apt clean` | Days 07, 09 |
| Where do I run all this? | `tmux` | Day 01 |

**Why inventory first.** You can't harden what you haven't identified. `hostnamectl` and `lscpu` say what the machine is (a VM or real hardware, which OS and kernel, how many CPUs), which decides what's worth protecting and how (a VM can be snapshotted before risky changes).

**A client is not the service.** `fail2ban-client` only talks to the fail2ban daemon through a socket file. If the daemon isn't running, the client has nobody to talk to, and says so.

**Watches, not alarms.** An `auditd` watch rule (`-w path -p wa -k key`) records writes and attribute changes to a file with a searchable key. It's loaded into the running kernel only, so it doesn't survive a reboot unless saved in `/etc/audit/rules.d/`.

**Config files for root tools must be root-owned.** `logrotate` ignores configs that aren't (Day 07's lesson), so a config is written with `sudo tee`.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working from `~/Desktop/github`)*

### 🖥️ Part A — Inventory: what is this machine?
```bash
$ hostnamectl
 Static hostname: Devil
       Icon name: computer-vm
         Chassis: vm
Chassis Asset Tag: No Asset Tag
      Machine ID: (hidden in this README)
         Boot ID: (hidden in this README)
    AF_VSOCK CID: (hidden in this README)
  Virtualization: vmware
Operating System: Kali GNU/Linux Rolling
          Kernel: Linux 7.1.5+kali-amd64
    Architecture: x86-64
 Hardware Vendor: VMware, Inc.
  Hardware Model: VMware Virtual Platform
Hardware Version: None
Firmware Version: 6.00
   Firmware Date: Thu 2020-11-12
    Firmware Age: 5y 11month 1w 3d

$ lscpu && free -h
Architecture:             x86_64
  CPU op-mode(s):         32-bit, 64-bit
  Address sizes:          45 bits physical, 48 bits virtual
  Byte Order:             Little Endian
CPU(s):                   4
  On-line CPU(s) list:    0-3
Vendor ID:                GenuineIntel
  Model name:             Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz
    CPU family:           6
    Model:                158
    Thread(s) per core:   1
    Core(s) per socket:   2
    Socket(s):            2
    Stepping:             10
    Microcode version:    0xffffffff
    BogoMIPS:             6000.02
    Flags:                fpu vme de pse tsc msr pae mce cx8 apic sep ... (long list)
Virtualization features:
  Hypervisor vendor:      VMware
  Virtualization type:    full
Caches (sum of all):
  L1d:                    128 KiB (4 instances)
  L1i:                    128 KiB (4 instances)
  L2:                     1 MiB (4 instances)
  L3:                     18 MiB (2 instances)
NUMA:
  NUMA node(s):           1
  NUMA node0 CPU(s):      0-3
Vulnerabilities:
```
*(The screenshot ends at the `Vulnerabilities:` line, so the `free -h` output isn't shown. The Machine ID, Boot ID and VSOCK ID are unique identifiers, so I've masked them here.)*

What it says:

- **It's a virtual machine:** `Virtualization: vmware`, `Chassis: vm`, hardware model `VMware Virtual Platform`. `Firmware Age: 5y 11month` is the date of the hypervisor's virtual firmware, not a physical BIOS I could update.
- **OS and kernel:** Kali GNU/Linux Rolling, Linux `7.1.5+kali-amd64`, 64-bit.
- **CPU:** 4 virtual CPUs (2 sockets × 2 cores × 1 thread), an Intel Core i5-8500 at 3.00 GHz as presented by the hypervisor, full virtualization.

### 🚫 Part B — Brute-force defense: is fail2ban up?
```bash
$ sudo fail2ban-client status
2026-10-23 16:58:08,136 fail2ban  [27321]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?

$ sudo fail2ban-client status sshd
2026-10-23 16:58:17,924 fail2ban  [27442]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?
```
**This is the key finding of the day: on 23 October at 16:58 the fail2ban daemon was not running, so nothing on this machine was banning brute-force attempts.** It's the same socket error from Day 06. Both commands fail identically because they're only clients; with no daemon behind the socket, neither a status check nor a ban can work.

The likely reason: on Day 06 the service was only *restarted*, never *enabled*, so it would not start again after the VM was rebooted. *(A guess, not yet checked: `systemctl is-enabled fail2ban` would confirm it.)* The fix is `sudo systemctl enable --now fail2ban`, which starts it now and on every boot, then `sudo fail2ban-client status` to verify.

### 🔎 Part C — Audit trail: watch a security config
```bash
$ sudo apt install auditd audispd-plugins -y
auditd is already the newest version (1:4.1.2-1+b2).
audispd-plugins is already the newest version (1:4.1.2-1+b2).
...
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354

$ sudo systemctl enable --now auditd

$ sudo auditctl -w /etc/ssh/sshd_config -p wa -k ssh_config_watch
Old style watch rules are slower

$ sudo auditctl -l
-w /etc/ssh/sshd_config -p wa -k ssh_config_watch
```
auditd was already installed. The rule means: **watch `/etc/ssh/sshd_config`, log writes (`w`) and attribute changes (`a`), and label the events `ssh_config_watch`.** The line `Old style watch rules are slower` is a note from `auditctl`, not an error: the rule was accepted, as `auditctl -l` proves by listing it. I chose the SSH daemon's config because it's the file an attacker would edit to weaken remote access.

### 🧹 Part D — Housekeeping
```bash
$ sudo apt autoremove
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354

$ sudo apt clean
```
`apt autoremove` removes dependency packages nothing needs any more, and here it removed **0** packages. `apt clean` deletes the downloaded `.deb` files kept in the package cache (`/var/cache/apt/archives`) and, as normal, prints nothing when it succeeds. That's a cheap way to get disk space back, the kind of thing `ncdu` from Day 09 would point at.

### 🔄 Part E — Rotating a log with `copytruncate`
```bash
$ mkdir -p ~/logrotate-lab && echo "Initial log entry" >> ~/logrotate-lab/app.log

$ printf '%s\n' "$HOME/logrotate-lab/app.log {" "    size 1" "    copytruncate" "    rotate 2" "    missingok" "    notifempty" "}" | sudo tee /etc/logrotate.d/copytruncate-demo
/home/ruin/logrotate-lab/app.log {
    size 1
    copytruncate
    rotate 2
    missingok
    notifempty
}

$ sudo logrotate -vf /etc/logrotate.d/copytruncate-demo
reading config file /etc/logrotate.d/copytruncate-demo
acquired lock on state file /var/lib/logrotate/status
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries
Creating new state
Creating new state
... (many more "Creating new state" lines)
```
This time **logrotate accepted the config**: it read it and went on to lock and read the state file, with no `file owner is wrong` error like on Day 07. The difference is how the config was written: `printf ... | sudo tee /etc/logrotate.d/...` makes the file root-owned, in the place logrotate trusts. The rule itself: rotate `app.log` once it passes 1 byte, keep 2 old copies, and use `copytruncate` so a process holding the file open keeps writing to it.

*(The screenshot ends in the middle of the "Creating new state" lines, before logrotate prints what it did to `app.log`, so the rotation result isn't captured.)*

---

## 🔬 Reference: What to Look for After the Forced Rotation

> ⚠️ **Not from my machine.** This describes what the config in Part E is designed to produce. It is not my captured output.

| Check | What to expect |
| --- | --- |
| `ls -lh ~/logrotate-lab/` | `app.log` still exists but is **0 bytes** (truncated, not replaced), and a rotated copy `app.log.1` appears (no `.gz`, since this config has no `compress`) |
| `cat ~/logrotate-lab/app.log.1` | the line `Initial log entry` |
| A process still writing to `app.log` | keeps writing to the **same file** after rotation: same PID, same inode |
| The `logrotate -vf` output after "Creating new state" | a `rotating pattern: ... forced from command line` line and `considering log /home/ruin/logrotate-lab/app.log` |

**Reading an audit event back (for Part C):** after `sudo chmod 644 /etc/ssh/sshd_config` (re-applies the normal permissions, changes nothing else), `sudo ausearch -k ssh_config_watch -i | tail -20` shows the event. The fields to read are `syscall` (what happened), `uid` (who it ran as), `auid` (who really logged in, which `sudo` doesn't change), `comm`/`exe` (which program) and `name=` (which file).

---

## 📋 Hardening Scorecard

Each row below rests on what I actually ran today:

| Area | Tool (day) | Status | Evidence in one line |
| --- | --- | --- | --- |
| Machine inventory | hostnamectl, lscpu | ✅ OK | VMware VM, Kali Rolling, 4 vCPUs, kernel 7.1.5 |
| Brute-force defense | fail2ban (06) | ⚠️ Needs work | `fail2ban-client` fails with a socket error: daemon not running |
| Audit trail | auditd (08) | ✅ OK, partial | watch rule on `sshd_config` is loaded (`auditctl -l`); no event read back yet |
| Housekeeping | apt autoremove / clean (09) | ✅ OK | nothing to remove, package cache cleared |
| Log retention | logrotate + copytruncate (07) | ℹ️ Partial | root-owned config was accepted; the rotation result isn't captured |

**Weakest spot, and the first thing to fix:** the brute-force defense, because fail2ban isn't running, so nothing is banning repeated failed SSH logins on this machine. First fix: `sudo systemctl enable --now fail2ban`, then `sudo fail2ban-client status sshd` to confirm the jail is up.

**Not covered today:** exposed ports and the firewall state. The project script from this phase (`sudo bash sysaudit.sh`) covers both, plus SSH settings, disk and accounts, in one scorecard.

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Two Commands, One Error**
> `fail2ban-client status` and `fail2ban-client status sshd` gave the identical error. Why, and what does it say about the whole machine?

<details>
<summary>My answer</summary>

Both are only clients that talk to the fail2ban daemon through `/var/run/fail2ban/fail2ban.sock`. The error means that socket doesn't exist, so the daemon isn't running, and the jail name makes no difference. For the machine it means the brute-force defense was **off** at 16:58 on 23 October: failed SSH logins could repeat without limit. A tool being installed isn't the same as it protecting the machine.

</details>

> **🥊 Challenge 2: The Rule I Loaded**
> Describe the audit rule in plain words, and say whether the "Old style watch rules are slower" line means it failed.

<details>
<summary>My answer</summary>

`-w /etc/ssh/sshd_config -p wa -k ssh_config_watch` means: watch that file, log any write or attribute change, and tag the events `ssh_config_watch` so I can search for them. The "old style" line is a note that this watch syntax is slower than the newer syscall-style rule, not a failure: `auditctl -l` lists the rule, so it's active. Because it was added with `auditctl` only, it will disappear on reboot unless it's saved under `/etc/audit/rules.d/`.

</details>

> **🥊 Challenge 3: Accepted This Time**
> On Day 07 logrotate rejected my config; today it accepted it. What changed?

<details>
<summary>My answer</summary>

Who owns the config file. On Day 07 I piped the config through `/dev/stdin`, owned by my user, and logrotate refused it ("file owner is wrong"). Today I wrote it with `sudo tee` into `/etc/logrotate.d/`, so root owns it, and logrotate went on to lock and read its state file. logrotate runs as root and configs can contain scripts, so it only trusts root-owned ones.

</details>

> **🥊 Challenge 4: Why Inventory First?**
> `hostnamectl` and `lscpu` don't harden anything. Why start there?

<details>
<summary>My answer</summary>

Because every later decision depends on what the machine is. Today's answer: a VMware virtual machine running Kali Rolling with 4 vCPUs. That tells me hardware firmware isn't mine to patch, that a snapshot is available before risky changes, and which kernel and OS to look up if I'm checking for vulnerabilities.

</details>

---

## 🧩 Quick Brain Check

1. Why do `fail2ban-client status` and `fail2ban-client status sshd` fail the same way?
2. What's the difference between `systemctl restart` and `systemctl enable --now` for fail2ban?
3. What do `-w`, `-p wa` and `-k` mean in an `auditctl` rule?
4. Why was the config accepted today but rejected on Day 07?
5. What does `apt clean` remove, and why does it print nothing?
6. Which area on the scorecard needs work first, and why?

---

## 🐛 Errors / Gotchas I Hit

- **fail2ban wasn't running** (`Failed to access socket path ... Is fail2ban running?`). Starting it and enabling it at boot is `sudo systemctl enable --now fail2ban`. Day 06 only used `restart`, which doesn't survive a reboot.
- **My audit watch is still loaded.** An `auditctl -w` rule stays active until reboot or removal. To remove just this one: `sudo auditctl -W /etc/ssh/sshd_config -p wa -k ssh_config_watch`.
- **The demo logrotate config is still in `/etc/logrotate.d/`.** logrotate's daily run will keep processing `copytruncate-demo` until it's removed: `sudo rm /etc/logrotate.d/copytruncate-demo` and `rm -rf ~/logrotate-lab`.
- **No `su` line in that config.** The log lives in a folder my own user owns; if logrotate skips it for "insecure permissions," the message would be in the lines after my screenshot ends. Adding `su ruin ruin` inside the block is the usual fix. *(Not seen, not confirmed.)*
- **`apt autoremove` removed nothing.** Earlier `apt install` outputs listed packages as "no longer required," but this run reported `Removing: 0`. I didn't investigate why.
- **The screenshot cut-offs:** the `lscpu` output stops before `free -h`, and the logrotate output stops before its result lines.

---

## 🔐 Security Relevance

The finding that matters is a defense that was silently off: fail2ban was installed and configured, yet protecting nothing. Checking that services are *running* (and enabled at boot), not just installed, is a basic audit step. The auditd watch on `sshd_config` is the other half: if someone weakens SSH, the change is logged with the real user (`auid`) even if they used `sudo`. And once the log files from these tools exist, `logrotate` and `apt clean` keep the disk from becoming the next problem.

---

## 🧠 Today's Takeaway

A hardening review is mostly asking "is it actually on?" Inventory told me what the machine is, the audit rule is in place on the SSH config, the log rotation config was accepted once it was root-owned, and the housekeeping is done. The one red item, fail2ban not running, is the best result of the lab: it's the kind of thing a quick scorecard exists to catch.

---

## 🏆 Phase 2 Wrap-Up: Sysadmin Days 01-10

| Day | Tool | One-line lesson |
| --- | --- | --- |
| 01 | tmux | one terminal, many panes and sessions that survive a disconnect |
| 02 | lsof | every open file and port has an owner, even deleted ones |
| 03 | strace | system calls show what a program really does |
| 04-05 | iptables | rules are checked in order; saved rules survive, unsaved ones don't |
| 06 | fail2ban | failed logins counted, offenders banned through a firewall chain |
| 07 | logrotate | rotation keeps logs bounded, config must be root-owned |
| 08 | inotifywait | live events for a file: opened, read, modified, closed |
| 09 | ncdu | find the disk hog; a deleted file can still use space |
| 10 | capstone | check that each defense is actually running |

---

⬅️ [Back to Sysadmin index](/Sysadmin) | ➡️ Next up: **Phase 3 — Pentesting, Day 01: theHarvester**
