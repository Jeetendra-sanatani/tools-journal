# 🔬 Sysadmin Day 03: strace (Trace a Program's System Calls)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_03-blue?style=for-the-badge" alt="Day 03"/>
  <img src="https://img.shields.io/badge/tool-strace-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Two failures, side by side, that look identical to a user but are completely different underneath — plus catching a process mid-sleep and watching strace describe exactly what it was doing when it got interrupted. 🔬

---

## 🏆 Day 02 Recap — The lsof-by-Path Limitation

`lsof /path/to/file` has to `stat()` the path before it can search for it, so once a file is deleted, that lookup fails outright — it doesn't show `(deleted)`, it just errors. The fix is to ask by process (`lsof -p <PID>`) or system-wide (`lsof +L1`), neither of which depends on the path still existing.

---

## 🎯 Mission Briefing

`strace` shows every system call a program makes, in the order it makes them. The real test today was whether two different kinds of failure — "permission denied" and "file doesn't exist" — actually look different at that level, even though a program's own error message makes them sound almost the same.

```
🔬 MISSION: Watch a Program Talk to the Kernel
──────────────────────────────────────────
[ ] Trace a simple command start to finish, read a summary table (Part A): not done
[~] Filter to one category of syscalls: done, but for FILE operations, not network
[x] Attach to an already-running process by PID
[x] Compare EACCES vs ENOENT for two different real failures
──────────────────────────────────────────
STATUS: Sysadmin Day 03 — Partly done (Part A and the network trace pending)
```

---

## ⚡ Quick Theory

**Every `openat()` line tells its own story.** The path being opened, the flags it's opened with, and the return value: a positive number is a file descriptor (success), `-1` is failure, followed by the exact kernel error code.

**EACCES and ENOENT are not the same failure.** `EACCES` means the file exists and was *found*, but the permission bits refuse this access. `ENOENT` means the path couldn't be found at all — no file, no permission check even attempted. A program's own message ("Permission denied" vs "No such file or directory") hints at this, but strace shows the kernel's exact reasoning, not a translated guess.

**A trace is full of "failures" that aren't really failures.** Before a program even gets to the file it's working with, the C library probes several locale and cache files (`/usr/share/locale/locale.alias`, `.../LC_MESSAGES/libc.mo`, and similar) that usually don't exist on a minimal system. Every one of those shows up as `ENOENT` too. Reading a trace means telling that routine background noise apart from the one `ENOENT` or `EACCES` that's actually the answer to the question being asked.

**Attaching to a running process catches it mid-syscall.** If a process is blocked inside a system call (like `sleep` waiting inside `clock_nanosleep`), `strace -p` doesn't wait for the next call — it shows the one already in progress, reported as `restart_syscall(<... resuming interrupted clock_nanosleep ...>`. Detaching with Ctrl+C leaves the process exactly as it was, uninterrupted.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🔎 EACCES vs ENOENT — the core comparison
```bash
$ mkdir -p ~/Desktop/sysadmin-lab/trace-failures
$ cd ~/Desktop/sysadmin-lab/trace-failures
$ chmod 000 sample.txt
```
```bash
$ strace -e trace=openat cat missing.txt
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "missing.txt", O_RDONLY) = -1 ENOENT (No such file or directory)
cat: missing.txt: No such file or directory
+++ exited with 1 +++
```
```bash
$ strace -e trace=openat cat sample.txt
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "sample.txt", O_RDONLY) = -1 EACCES (Permission denied)
cat: sample.txt: Permission denied
+++ exited with 1 +++
```
(Both runs also triggered several more `ENOENT` lines for `/usr/share/locale/...` lookups — the routine locale-file noise described above, not shown twice here since it's identical both times.)

Line for line, the only thing that changes between these two traces is the `openat()` result for the target file itself: `missing.txt` never gets past "does this path exist" (`ENOENT`), while `sample.txt` is found but refused (`EACCES`) — exactly the two different reasons `chmod 000` and a genuinely absent file would produce.

### 🗂️ A bonus: the one that didn't show up
```bash
$ strace -e trace=openat ls /not-a-real-directory
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
...
openat(AT_FDCWD, "/proc/filesystems", O_RDONLY|O_CLOEXEC) = 3
...
ls: cannot access '/not-a-real-directory': No such file or directory
+++ exited with 2 +++
```
No `openat()` line for `/not-a-real-directory` itself appears anywhere in this trace, even though `ls` clearly detected it's missing (exit code `2`, a different exit code from `cat`'s `1`). `ls` must be checking the path with a different syscall — `statx` or `newfstatat` rather than `openat` — which this filter didn't ask for. A filtered trace only shows what you told it to look for; the real failure can be happening in a syscall that isn't in the list.

### 🔍 Filtering to one category — substituted with directory listing instead of network
```bash
$ strace --version
strace -- version 7.0
Copyright (c) 1991-2026 The strace developers <https://strace.io>.
...

$ strace -e trace=openat,getdents64,close ls
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libselinux.so.1", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, "/proc/filesystems", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
close(3)                               = 0
openat(AT_FDCWD, ".", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
getdents64(3, 0x55cc16e92d50 /* 56 entries */, 32768) = 1920
getdents64(3, 0x55cc16e92d50 /* 0 entries */, 32768) = 0
close(3)                               = 0
12345  amass_screenshot_output.txt  day67.gnmap  ...  tesla_crt.html
...
close(1)                               = 0
close(2)                               = 0
+++ exited with 0 +++
```
This wasn't the network trace the lab sheet asked for (`curl` wasn't tested), but it's a genuinely clear look at how `ls` actually works: open each shared library it needs and close it right away, open `/proc/filesystems` and the locale archive the same way, then open `.` itself specifically **as a directory** (`O_DIRECTORY` flag), read its contents with `getdents64` (56 entries in one call, then a second call returning 0 entries to signal "that's everything"), and close it. `ls` never uses plain `read()` on a directory — directories are listed with `getdents64`, a different syscall entirely from reading a regular file.

### 🧟 Attaching to a running process
```bash
$ pgrep -a sleep
8878 sleep 300

$ ps -p 8878 -o pid,comm,args
  PID COMMAND         COMMAND
 8878 sleep           sleep 300

$ sudo strace -p 8878
strace: Process 8878 attached
restart_syscall(<... resuming interrupted clock_nanosleep ...>
^Cstrace: Process 8878 detached
 <detached ...>
```
`pgrep -a` and `ps -p` confirmed PID `8878` was a real `sleep 300` already running. Attaching showed `restart_syscall(<... resuming interrupted clock_nanosleep ...>` — this is strace's accurate way of reporting that it attached to a process already blocked *inside* a syscall: `sleep` was mid-`clock_nanosleep`, and attaching itself briefly interrupts that call at the kernel level, so the next thing shown is the kernel restarting it. Ctrl+C detached cleanly, with no indication the process was harmed.

(A separate, shorter `sleep 300` was also started and stopped with Ctrl+C earlier in the same session — unrelated to PID 8878, just a quick first attempt before the real one shown above.)

---

## 🧪 What I Actually Found

- [x] `EACCES` (permission refused, file found) vs `ENOENT` (path not found at all) — confirmed as genuinely different kernel responses, for `sample.txt` (chmod 000) and `missing.txt` respectively
- [x] A filtered trace can miss the real failure entirely if it filters out the syscall actually involved — `ls`'s missing-directory check never showed up under an `openat`-only filter
- [x] `ls` reads directories with `getdents64` in a loop (growing entries, then a 0-entry call to signal the end), never with plain `read()`
- [x] `strace -p` on an already-running `sleep` showed it mid-`clock_nanosleep`, confirmed alive before and detached cleanly with Ctrl+C after
- [ ] Part A — a plain `strace ls /tmp` and its `-c` summary table (most-called syscall, time%): not run
- [ ] Network-category trace (`strace -e trace=network curl ...`) and its `connect()`/`socket()` calls: not run

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: The Missing Call**
> `strace -e trace=openat ls /not-a-real-directory` never showed a failed `openat()` for that path, even though `ls` clearly detected it was missing. What does this tell you about trusting a filtered trace?

<details>
<summary>My answer</summary>

A filtered trace only shows the syscalls you asked for — if the real check happens through a different one (here, almost certainly `statx` or `newfstatat`, not `openat`), filtering it out hides the exact moment that matters. The lesson: if a filtered trace doesn't show what you expected, the answer might be "wrong filter," not "nothing happened." Running `strace -f` with no filter, or adding `stat,statx,newfstatat` to the filter list, would likely have caught it.

</details>

> **🥊 Challenge 2: Same Message, Different Code**
> `cat missing.txt` and `cat sample.txt` (chmod 000) both print a short one-line error to the user. What's the one line in each strace trace that actually distinguishes them, and why does that distinction matter for troubleshooting?

<details>
<summary>My answer</summary>

The `openat()` line for the target file itself: `= -1 ENOENT (No such file or directory)` for the missing file, versus `= -1 EACCES (Permission denied)` for the existing-but-locked-down one. It matters because the fix is completely different — `ENOENT` means create or restore the file (or check the path/typo), while `EACCES` means fix permissions or ownership on a file that's already there. A user's error message alone doesn't always make that obvious at a glance, especially in a script's logs.

</details>

> **🥊 Challenge 3: Interrupted, Not Broken**
> Attaching strace to PID 8878 showed `restart_syscall(<... resuming interrupted clock_nanosleep ...>`. Did attaching strace break or restart the sleep's countdown?

<details>
<summary>My answer</summary>

No. `restart_syscall` is the kernel's own mechanism for resuming a system call that got interrupted (here, by strace attaching), picking up where it left off rather than starting over. The process wasn't killed, reset, or meaningfully disturbed — `ps -p 8878` before showed it alive and `sleep 300` still running, and detaching with Ctrl+C left it exactly as found, just observed briefly in the middle of its wait.

</details>

---

## 🧩 Quick Brain Check

1. What's the practical difference between `EACCES` and `ENOENT`, in terms of what each one tells you to check first?
2. Why do normal, successful commands still show several `ENOENT` lines in their trace (the locale-file lookups)?
3. What syscall does `ls` use to read a directory's contents, and how does it know when it's reached the end?
4. What does `restart_syscall` mean when it appears right after attaching strace to a running process?
5. Why might a trace filtered to only one or two syscalls completely miss the syscall responsible for a failure?

---

## 🐛 Errors / Gotchas I Hit

- `echo "..." > sample.txt` failed with `zsh: permission denied: sample.txt` before the trace even started — the file already existed from an earlier, unwritable state, which is exactly what made it useful for the `EACCES` test once `chmod 000` was applied on purpose.
- `strace -e trace=openat` on `ls /not-a-real-directory` never showed the actual failing syscall for that path — `ls` checks with something other than `openat` (most likely `statx`), which the filter excluded.
- Part A's plain trace + `-c` summary, and Part B's actual network-category trace against `curl`, weren't run this round — the file-category substitute (directory listing via `getdents64`) covered similar ground but not the same commands.

---

## 🔐 Security Relevance

Distinguishing `EACCES` from `ENOENT` matters directly in an investigation: a process repeatedly hitting `EACCES` on a sensitive file is trying to access something it's forbidden from, which is a very different signal from a process hitting `ENOENT` because a config file is simply missing. Tracing a program's actual syscalls — rather than trusting its own printed error — is also exactly how malware analysis starts: watching what a binary really does (which files, which network connections) regardless of what it claims to be doing.

---

## 🧠 Today's Takeaway

Two errors that sound almost identical to a user — "permission denied" and "no such file" — are genuinely distinct events at the syscall level, and strace makes that distinction visible instead of guessed. Just as useful: a filter that doesn't show what you expected is itself a clue, not a dead end, because the real syscall might just not be in the list you asked for.

---

⬅️ [Back to Sysadmin index](/Sysadmin) | ➡️ Next up: **Day 04: iptables Part 1 — tables, chains & basic rules**
