# 💽 Sysadmin Day 09: ncdu (Finding What's Eating Your Disk)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_09-blue?style=for-the-badge" alt="Day 09"/>
  <img src="https://img.shields.io/badge/tool-ncdu-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> `df` tells you the disk is filling up. `ncdu` tells you **where**. And one small experiment at the end shows the trap where the space is used by a file that no longer has a name. 💽

---

## 🏆 Day 07 Recap — logrotate

Day 07 showed how `logrotate` keeps logs under control with `rotate N`, `compress` and `delaycompress`. Today's tool is the other half of that job: finding the files that nothing is keeping in check, and checking whether rotation is really working.

---

## 🎯 Mission Briefing

```
💽 MISSION: Find the Disk Hog
──────────────────────────────────────────
[x] Install ncdu and take a baseline with df and du
[x] Explore /var/log with ncdu and read the biggest items
[x] Build my own test folder and see it in ncdu
[x] Create a "deleted but still open" file and find it in /proc
──────────────────────────────────────────
STATUS: Sysadmin Day 09 — Done
```

---

## ⚡ Quick Theory

**`ncdu` is `du` with a screen.** It scans a folder, then lets you sort by size and step into folders, so you can follow the biggest item down until you find the culprit.

**Keys inside ncdu (version 1.22 here):**

| Key | Action |
| --- | --- |
| `↑` `↓` | move the cursor |
| `Enter` / `→` | open the selected folder |
| `←` | go back up |
| `s` / `n` | sort by size / by name |
| `g` | toggle the bar graph |
| `a` | toggle apparent size vs disk usage |
| `i` | info about the selected item |
| `d` | **delete** the selected item |
| `q` | **quit** |

**Reading the screen:** a name starting with `/` is a folder, a name without it is a file, and an `e` in the left margin marks an **empty** folder. The bottom bar shows `Total disk usage` (space actually used on disk), `Apparent size` (the sizes the files report), and the item count.

**`df` vs `du`.** `df` asks the filesystem how much space is used in total. `du` and `ncdu` add up the files they can reach by name. Normally they agree. When they don't, a file may be using space without having a name any more.

**The deleted-but-open trap (Day 02 lsof).** Deleting a file removes its *name*. If a process still has the file open, the data stays on disk until that process lets go. The file is then invisible to `ls`, `du` and `ncdu`, but `/proc/<pid>/fd/` and `lsof +L1` still show it, marked `(deleted)`.

**Safer ncdu habit.** `ncdu -r` runs read-only (no delete key), and `-x` keeps it on one filesystem. Both are good defaults for system folders like `/var/log`.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working from `~/Desktop/github`)*

### 📊 Part A — The baseline with plain tools
```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            3.9G     0  3.9G   0% /dev
tmpfs           791M  1.5M  790M   1% /run
/dev/sda1        93G   28G   62G  31% /
tmpfs           3.9G  4.0K  3.9G   1% /dev/shm
none            1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
none            1.0M     0  1.0M   0% /run/credentials/systemd-resolved.service
tmpfs           3.9G  136K  3.9G   1% /tmp
none            1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs           791M  108K  791M   1% /run/user/1000

$ du -sh ~
2.6G    /home/ruin
```
The only real disk is `/dev/sda1`: 93 GB in total, 28 GB used, **62 GB free, 31% full.** Every other line is a memory-backed or tiny virtual filesystem. No separate `/home` mount appears, so my home folder (2.6 GB) lives on `/dev/sda1` too, as part of that 28 GB.

### 🔍 Part B — ncdu on `/var/log`
```bash
$ sudo apt install ncdu -y
ncdu is already the newest version (1.22-1).
...
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354

$ sudo ncdu /var/log
zsh: suspended  sudo ncdu /var/log
```
The `zsh: suspended` line is what the terminal printed when I left ncdu. It means ncdu was **stopped, not quit** (see Gotchas). The ncdu screen itself, sorted by size:

```
ncdu 1.22 ~ Use the arrow keys to navigate, press ? for help
--- /var/log ------------------------------------------------
  343.9 MiB [##############################] /journal
   17.2 MiB [#                             ] /installer
    1.0 MiB [                              ] /apache2
  552.0 KiB [                              ] /apt
  548.0 KiB [                              ]  dpkg.log.1
  364.0 KiB [                              ]  dpkg.log
  204.0 KiB [                              ]  dpkg.log.2.gz
  128.0 KiB [                              ]  vmware-vmusr-ruin.log
  104.0 KiB [                              ]  wtmp
   72.0 KiB [                              ]  vmware-vmtoolsd-root.log
   52.0 KiB [                              ] /lightdm
   44.0 KiB [                              ]  vmware-vmtoolsd-ruin.log
   40.0 KiB [                              ]  boot.log.4
   36.0 KiB [                              ]  alternatives.log.1
   24.0 KiB [                              ]  Xorg.1.log
   24.0 KiB [                              ]  Xorg.0.log.old
   24.0 KiB [                              ]  boot.log.6
   24.0 KiB [                              ]  boot.log.1
   24.0 KiB [                              ]  Xorg.0.log
   24.0 KiB [                              ]  boot.log
   16.0 KiB [                              ]  boot.log.5
   12.0 KiB [                              ] /runit
   12.0 KiB [                              ]  alternatives.log.2.gz
   12.0 KiB [                              ]  alternatives.log
   12.0 KiB [                              ]  boot.log.2
   12.0 KiB [                              ]  fontconfig.log
    8.0 KiB [                              ]  wtmp.db
    8.0 KiB [                              ] /inetsim
    8.0 KiB [                              ]  boot.log.3
    8.0 KiB [                              ]  boot.log.7
    8.0 KiB [                              ] /postgresql
    4.0 KiB [                              ]  lastlog
e   4.0 KiB [                              ] /sysstat
    4.0 KiB [                              ] /stunnel
e   4.0 KiB [                              ] /speech-dispatcher
e   4.0 KiB [                              ] /samba
e   4.0 KiB [                              ] /redis
e   4.0 KiB [                              ] /private
e   4.0 KiB [                              ] /openvpn
e   4.0 KiB [                              ] /notus-scanner
*Total disk usage: 364.6 MiB   Apparent size: 468.8 MiB   Items: 145
```
*(Transcribed from my screenshot, the bar graphs shortened to fit; the list on screen continued beyond `/notus-scanner`.)*

What stands out:

- **One item dominates:** `/journal` is 343.9 MiB of the 364.6 MiB total. Everything else in `/var/log` is small by comparison.
- **Rotation is visible:** numbered files (`boot.log` to `boot.log.7`, `dpkg.log.1`, `alternatives.log.1`) and compressed ones (`dpkg.log.2.gz`, `alternatives.log.2.gz`) are exactly what `rotate N` and `compress` from Day 07 produce.
- **The newest rotated copy is not compressed, the older ones are:** `dpkg.log.1` is plain text while `dpkg.log.2.gz` is gzipped. That's the pattern `delaycompress` creates, like the `ufw` config from Day 07.
- **Apparent size (468.8 MiB) is bigger than disk usage (364.6 MiB).** Disk usage counts space actually allocated; apparent size counts the sizes files report. A gap like this usually means some files are sparse (they claim more bytes than they occupy). I didn't check which files cause it here.
- **The `e` marks** in the left margin are empty folders (4 KiB is just the folder entry itself): `/sysstat`, `/speech-dispatcher`, `/samba`, `/redis`, `/private`, `/openvpn`, `/notus-scanner`.

### 🧪 Part C — ncdu on my own test folder
```bash
$ mkdir -p ~/ncdu-lab && dd if=/dev/zero of=~/ncdu-lab/testfile.bin bs=1M count=20 status=progress
20+0 records in
20+0 records out
20971520 bytes (21 MB, 20 MiB) copied, 0.0538207 s, 390 MB/s

$ ncdu ~/ncdu-lab
zsh: suspended  ncdu ~/ncdu-lab
```
The ncdu screen:
```
ncdu 1.22 ~ Use the arrow keys to navigate, press ? for help
--- /home/ruin/ncdu-lab ------------------------------------
   20.0 MiB [###############################] testfile.bin
*Total disk usage: 20.0 MiB   Apparent size: 20.0 MiB   Items: 1
```
`dd` wrote exactly `20 × 1 MiB` = 20,971,520 bytes, and ncdu shows the same 20.0 MiB, with one item. Here disk usage and apparent size agree, unlike in `/var/log`.

### 👻 Part D — A deleted file that is still open
```bash
$ echo "Sensitive test data" > ~/open-trap.txt
$ exec 3< ~/open-trap.txt
$ rm ~/open-trap.txt
$ ls -l /proc/$$/fd/3
lr-x------ 1 ruin ruin 64 Oct 23 16:50 /proc/3299/fd/3 -> '/home/ruin/open-trap.txt (deleted)'
```
Step by step:

1. `exec 3< ~/open-trap.txt` made **my own shell** open the file for reading on file descriptor 3.
2. `rm` deleted the file's name.
3. `/proc/$$/fd/3` (here `$$` = my shell's PID, **3299**) still points at the file, and the link target ends in **`(deleted)`**.

So the file is gone from the folder but still held open by process 3299. This is the Day 02 trap in its smallest form. The file here is a few bytes, so no change in free space is visible; with a big file, `df` would keep showing the space as used.

---

## 🔬 Reference: The Same Trap With a Big File

> ⚠️ **Not from my machine.** This is what the 100 MB version of Part D would show, as a reference for what to look for. I did not run it with a large file.

```bash
dd if=/dev/zero of=~/ncdu-lab/big.bin bs=1M count=100 status=none
sleep 600 < ~/ncdu-lab/big.bin &        # a process holding the file open
rm ~/ncdu-lab/big.bin
```

| Check | What to expect |
| --- | --- |
| `ls ~/ncdu-lab` and `ncdu ~/ncdu-lab` | `big.bin` is gone |
| `df -h ~` | **Used** has not dropped by ~100 MB |
| `sudo lsof +L1 \| grep big.bin` | the `sleep` process is listed, marked `(deleted)` |
| `kill` the holder, then `df -h ~` again | **Used** drops by ~100 MB: the space is freed only now |

For my small file, the matching ways to let go and to recover are `exec 3<&-` (closes descriptor 3) and `cat /proc/3299/fd/3` (reads the deleted file's content back while it's still open).

---

## 🧪 What I Actually Found

- [x] The only real disk, `/dev/sda1`, is 93 GB with 62 GB free (31% used); my home folder is 2.6 GB of that
- [x] `/var/log` totals 364.6 MiB, and **343.9 MiB of it is the `/journal` folder**
- [x] Log rotation is clearly working: numbered copies, `.gz` for older ones, uncompressed for the newest rotated copy
- [x] In `/var/log`, apparent size (468.8 MiB) is larger than disk usage (364.6 MiB)
- [x] In my own test folder, a 20 MiB file showed up as exactly 20.0 MiB in ncdu
- [x] A deleted-but-open file is still reachable at `/proc/<pid>/fd/<n>`, marked `(deleted)`, held by my shell (PID 3299)
- [x] Leaving ncdu with the wrong key left it **suspended** in the background (twice)

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Biggest Item**
> What's the biggest thing in `/var/log`, and would a `logrotate` rule from Day 07 manage it?

<details>
<summary>My answer</summary>

`/journal`, at 343.9 MiB, which is about 94% of the folder. It holds the systemd journal, and as far as I know that is managed by `systemd-journald`'s own size limits (set in `journald.conf`), not by a `logrotate` config. The plain log files next to it (`dpkg.log`, `boot.log`, `alternatives.log`) are the ones logrotate-style rotation applies to, and they're all tiny.

</details>

> **🥊 Challenge 2: Is Rotation Working?**
> What in the screenshot proves that rotation is happening?

<details>
<summary>My answer</summary>

The numbered copies and the `.gz` files. `boot.log` has copies up to `.7`, `dpkg.log` has `.1` and `.2.gz`, and `alternatives.log` has `.1` and `.2.gz`. The newest rotated copy (`.1`) is uncompressed while the older one is gzipped, which is the same pattern `compress` plus `delaycompress` made in the `ufw` config on Day 07.

</details>

> **🥊 Challenge 3: Two Sizes**
> Why can `Total disk usage` and `Apparent size` differ, and which one should I trust for "how much space is this using?"

<details>
<summary>My answer</summary>

Disk usage is the space actually allocated on the disk; apparent size is the total of the sizes the files report. For "how much space does this really take," disk usage is the one to trust. Here `/var/log` showed 364.6 MiB used vs 468.8 MiB apparent, probably because some files are sparse. In my test folder both numbers were 20.0 MiB because `dd` wrote real data with no holes.

</details>

> **🥊 Challenge 4: Where Did the File Go?**
> I deleted `~/open-trap.txt`, yet `/proc/3299/fd/3` still points at it. What is holding it, and when will the space be freed?

<details>
<summary>My answer</summary>

My own shell (PID 3299) is holding it: `exec 3<` opened it on descriptor 3. Deleting only removed the name, so `ls`, `du` and `ncdu` can't see it, but the data stays on disk until the last open handle closes. Closing the descriptor with `exec 3<&-` (or exiting that shell) would free it. With a large file, `df` would keep counting the space until then.

</details>

---

## 🧩 Quick Brain Check

1. How do you tell a folder from a file on the ncdu screen, and what does an `e` in the margin mean?
2. What's the difference between `Total disk usage` and `Apparent size`?
3. Why is `ncdu -r -x` a safer way to explore `/var/log`?
4. After `rm`, why can a file still use disk space, and where can you still see it?
5. What does `zsh: suspended ncdu` mean, and how should I leave ncdu instead?

---

## 🐛 Errors / Gotchas I Hit

- **`zsh: suspended  ncdu` (both runs):** that line means ncdu was stopped, not quit, probably by pressing Ctrl-Z. Inside ncdu, **`q`** quits. A suspended ncdu is still alive in the background (`jobs` lists it, `fg` brings it back, `kill %1` ends it), and the one on `/var/log` was running as root.
- **ncdu ran without `-r`:** `sudo ncdu /var/log` has the delete key switched on. I didn't press it, but `sudo ncdu -r -x /var/log` is the safe form for system folders.
- **A tiny deleted file doesn't change `df`:** my test file in Part D held a few bytes, so there was nothing to see in the free space. The effect only becomes visible with a large file, as in the reference section.
- **ncdu versions differ:** this is 1.22; newer 2.x versions have extra options and slightly different keys.

---

## 🔐 Security Relevance

A full disk is an availability problem: logs that grow without limit can stop services from writing, and `ncdu` is the fastest way to find the cause. The `(deleted)` marker matters for security too: attackers and malware sometimes delete their own file after starting it, so `ls` shows nothing, but `ls -l /proc/<pid>/fd` and `lsof +L1` still expose it, and its content can be copied back out of `/proc` while the process runs. It's the same trick as today's lab, used for investigation.

---

## 🧠 Today's Takeaway

`df` says how full the disk is and `ncdu` says what is filling it: on this machine, `/var/log` is 364.6 MiB and almost all of it is the journal, while the rotated logs beside it show Day 07's rules at work. The last lesson is the deleted-but-open file: removing a name doesn't free space until the last process lets go, and `/proc/<pid>/fd` is where that ghost can still be found.

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 10: Capstone — mini server hardening & audit**
