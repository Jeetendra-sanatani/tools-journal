# 🔎 Sysadmin Day 02: lsof (List Open Files)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_02-blue?style=for-the-badge" alt="Day 02"/>
  <img src="https://img.shields.io/badge/tool-lsof-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> A real port conflict, caught in the act, and an lsof limitation that trips up even experienced sysadmins: it can't find a file by path once the path is gone. 🔎

---

## 🏆 Day 01 Recap — The tmux Nesting Issue

Day 01's lab ran almost entirely inside a single tmux session that was never actually detached from, so every `tmux attach`/`tmux new` attempt hit the "sessions should be nested with care" warning. The fix: detach for real with `Ctrl+b d`, confirm with `echo $TMUX` (empty outside, a socket path inside), then redo the window/pane splits. That redo is still open — revisit when there's time.

---

## 🎯 Mission Briefing

`lsof` lists every file a process has open right now, including network sockets. Today's goal was four things: see what's listening, see what a specific process has open, catch a real port conflict, and find a deleted-but-still-open file. Three of those happened; the fourth revealed something more interesting than expected.

```
🔎 MISSION: See What's Actually Open, Right Now
──────────────────────────────────────────
[x] Confirm exactly what's listening on a port with lsof -i
[x] Trigger and read a genuine port-already-in-use error
[~] Find a deleted-but-open file: the planned method didn't work, and that's the finding
[ ] lsof -p / -c on a specific process (Part B): not done yet
[ ] fuser 8080/tcp, compared against lsof's answer: not done yet
──────────────────────────────────────────
STATUS: Sysadmin Day 02 — Partly done (2 items pending)
```

---

## ⚡ Quick Theory

**`lsof -i :<port>` identifies a listener by what's already open**, matching it up by the kernel's own record of which process holds which socket. It doesn't need the port's history, just its current state.

**`lsof <path>`, by contrast, needs to `stat()` the path first.** Before lsof can tell you which processes have a file open, it has to resolve that path to a device and inode number, then search its scan of every process's open file table for a match. If the path doesn't exist anymore, `stat()` fails immediately, and lsof can't even start the search, no matter how many processes are still holding that file open by its old inode.

**The two correct ways to find a deleted-but-open file don't depend on the path still existing:**
```
sudo lsof -p <PID>     ->  ask by PROCESS, not by path; a deleted file still shows up
                           in that process's file list, usually marked (deleted)
sudo lsof +L1           ->  ask SYSTEM-WIDE for anything with a link count of 0
                           (a deleted file still occupies disk space until the
                           last process holding it closes it)
```

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🔍 Confirming the listener
```bash
$ sudo lsof -i :8080
COMMAND   PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3 74276  ruin    3u  IPv4 148119      0t0  TCP *:http-alt (LISTEN)
```
PID `74276`, owned by `ruin`, file descriptor `3u` (open for both read and write), listening on all interfaces. `http-alt` is just `/etc/services`' name for port 8080 — the same "service name instead of a number" behavior nmap showed back on Networking Day 04.

### 💥 A genuine port conflict
```bash
$ python3 -m http.server 8080
Traceback (most recent call last):
  File "<frozen runpy>", line 203, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/usr/lib/python3.14/http/server.py", line 1436, in <module>
    test(
    ...
  File "/usr/lib/python3.14/http/server.py", line 1352, in test
    server = ServerClass(addr, HandlerClass)
  File "/usr/lib/python3.14/socketserver.py", line 457, in __init__
    self.server_bind()
  File "/usr/lib/python3.14/http/server.py", line 1423, in server_bind
    return super().server_bind()
  File "/usr/lib/python3.14/http/server.py", line 148, in server_bind
    socketserver.TCPServer.server_bind(self)
  File "/usr/lib/python3.14/socketserver.py", line 478, in server_bind
    self.socket.bind(self.server_address)
OSError: [Errno 98] Address already in use
```
This is the real version of what the lab asked for: a second server trying to bind the same port the first one already owns. `Errno 98` is the kernel's `EADDRINUSE`, and the traceback shows exactly where in Python's own `http.server` module the failure happens — `socket.bind()`, inside `server_bind()`, called from `TCPServer.__init__`. `lsof -i :8080` above is how you'd find the first server's PID to stop it, freeing the port for the second one.

### 🗑️ The deleted-file trick — and the limitation it revealed
```bash
$ echo "temporary data" > /tmp/deleteme.txt
$ tail -f /tmp/deleteme.txt &
[2] 98969
temporary data

$ rm /tmp/deleteme.txt

$ ls -la /tmp/deleteme.txt 2>&1
ls: cannot access '/tmp/deleteme.txt': No such file or directory

$ sudo lsof /tmp/deleteme.txt
lsof: WARNING: can't stat() fuse.gvfsd-fuse file system /run/user/1000/gvfs
      Output information may be incomplete.
lsof: WARNING: can't stat() fuse.portal file system /run/user/1000/doc
      Output information may be incomplete.
lsof: status error on /tmp/deleteme.txt: No such file or directory

$ kill $TAILPID
[2]  - terminated  tail -f /tmp/deleteme.txt
```
Everything up to the `lsof` line went exactly as expected: `tail -f` (PID `98969`) kept the file open, `rm` deleted the directory entry, and `ls` confirmed the name was gone. But `sudo lsof /tmp/deleteme.txt` didn't show the file as `(deleted)` the way the lab sheet expected — it failed outright with `status error ... No such file or directory`. That's the theory above happening in real time: lsof tried to `stat()` a path that no longer exists, got nothing back, and gave up before it ever got to check which processes had it open. The two FUSE warnings above it (`gvfsd-fuse`, `fuse.portal`) are unrelated noise from Kali's GNOME desktop integration mounts and have nothing to do with the actual test. `kill $TAILPID` correctly stopped job `[2]`, confirming `tail -f` really had been holding the file the whole time — just not reachable by path anymore.

---

## 🧪 What I Actually Found

- [x] `lsof -i :8080` identified the exact listener: PID 74276, user `ruin`, fd `3u`
- [x] A real second-server-same-port attempt failed with `OSError: [Errno 98] Address already in use`
- [x] `tail -f` (PID 98969) kept `/tmp/deleteme.txt` open through an `rm`, confirmed by `ls` showing it gone
- [x] `lsof /tmp/deleteme.txt` failed with a `status error`, not a `(deleted)` result — because lsof-by-path needs the path to still exist
- [ ] Confirming the file the "right" way, with `lsof -p 98969` or `lsof +L1`: not run (the process was killed before trying)
- [ ] `sudo fuser 8080/tcp`, compared against `lsof`'s PID: not done
- [ ] `lsof -p <PID>` / `lsof -c bash` on a chosen process (Part B): not done

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Two Ways to Ask the Same Question**
> `lsof /tmp/deleteme.txt` failed once the file was deleted. Write the two commands that WOULD have found it anyway, and explain why each one sidesteps the problem that broke the path-based lookup.

<details>
<summary>My answer</summary>

```bash
sudo lsof -p 98969      # ask by the process that's holding it, not by the file's path
sudo lsof +L1            # ask system-wide for anything with a link count of 0
```
`-p 98969` never needs to resolve a path at all — it just lists everything that specific process already has open, which still includes the deleted file by its old inode. `+L1` searches every open file across every process for one whose link count dropped to zero (exactly what happens when the last directory entry pointing at a file is removed), which also doesn't require the original path to resolve.

</details>

> **🥊 Challenge 2: Why `stat()` Matters**
> `lsof <path>` and `lsof -p <PID>` both eventually find the same kernel-level information about an open file. Why does only one of them fail once the file is deleted?

<details>
<summary>My answer</summary>

`lsof <path>` has to translate a path into a device+inode pair before it can search anything, and that translation is done with `stat()`, which only works on paths that currently exist. `lsof -p <PID>` skips that step entirely — it goes straight to the kernel's record of what PID 98969 has open, which still points at the old inode even though no directory entry leads to it anymore. The deleted file genuinely still exists on disk (that's why `kill $TAILPID` was needed to let the space be reclaimed); it's only the NAME that's gone, and `stat()` only works on names.

</details>

> **🥊 Challenge 3: Confirming the Port Is Actually Free**
> After fixing a port conflict by killing the original process, what's the fastest way to confirm the port is genuinely free again, rather than just assuming the `kill` worked?

<details>
<summary>My answer</summary>

Re-run the same check that found it in the first place: `sudo lsof -i :8080`. If the port is free, it prints nothing at all (empty output, not an error). Trying to start a new server on that port and watching it succeed is a valid confirmation too, but `lsof -i` is quicker and doesn't commit to actually binding anything.

</details>

---

## 🧩 Quick Brain Check

1. Why does `lsof /path/to/file` need the file to currently exist, while `lsof -p <PID>` doesn't?
2. What does `Errno 98` / `Address already in use` actually mean at the kernel level?
3. What does file descriptor `3u` tell you, versus just `3`?
4. Why does a deleted file still take up real disk space until every process with it open closes it?
5. What does `lsof +L1` search for, specifically?

---

## 🐛 Errors / Gotchas I Hit

- `sudo lsof /tmp/deleteme.txt` failed with `status error ... No such file or directory` instead of showing `(deleted)` — this is lsof's own `stat()`-based limitation when a path no longer exists, not a mistake in the test setup. `lsof -p <PID>` or `lsof +L1` are the correct tools for this once the path is gone.
- The FUSE warnings (`gvfsd-fuse`, `fuse.portal`) that appeared alongside the real error are unrelated desktop-integration noise from Kali's GNOME session, not part of the actual test.
- Part B (`lsof -p` / `lsof -c` on a chosen process) and the `fuser 8080/tcp` comparison from Part C weren't run this round.

---

## 🔐 Security Relevance

Checking `lsof -i` before trusting that a port is free (or, defensively, auditing it regularly) is how an unexpected listener gets caught — a service that shouldn't be running, bound to a port nobody remembers opening. The deleted-file trick has a security angle too: a process that opens a file and then deletes it, so the data only exists in memory and in that process's hidden open-file-table entry, is a technique sometimes used to hide activity from a casual `ls` of the filesystem. Knowing to check `lsof -p <PID>` or `lsof +L1` rather than trusting a path lookup is exactly what catches that.

---

## 🧠 Today's Takeaway

`lsof -i` cleanly found the exact process squatting on a port, and the real conflict error (`Errno 98`) confirmed it. The more valuable lesson came from the trick that "failed": `lsof <path>` depends on `stat()`, which depends on the path still existing — once it's deleted, you have to ask by PID or search system-wide instead. A tool failing in a way that reveals how it actually works is worth more than it succeeding quietly would have been.

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 03: strace — trace a program's system calls**
