# 🧪 Lab Sheet — Sysadmin Day 09: ncdu (Finding What's Eating Your Disk)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

`ncdu` is `du` with an interactive, sortable screen: you see which folder is biggest, step into it, and keep going until you find the culprit. It connects two earlier days: **Day 07's logrotate** (logs are the classic disk hog) and **Day 02's lsof** (the "deleted but still open" file that `du` can't see but `df` can).

---

## ⚠️ Scope for today

- **Only explore system folders in read-only mode.** Always start `ncdu` on system paths with `-r` (read-only), which switches off its delete feature. You can't delete something by accident with a stray `d` keypress.
- **Deleting is allowed only inside `~/ncdu-lab`**, the folder you create yourself in Part C.
- Check free space first (Step 0). Part D creates a 100 MB file, so you need a few hundred MB free.
- Scanning a big folder (like `/var`) can take a few seconds. Wait for the scan to finish before pressing keys.

---

## Step 0: Install and check free space
```bash
sudo apt install -y ncdu
ncdu --version
df -h             # disk space per filesystem
df -i             # inodes per filesystem (a disk can be "full" of tiny files even with space free)
```

---

## Part A: the "before ncdu" view with plain tools

```bash
# A1 - which filesystem is fullest?
df -h | sort -k5 -h | tail -5

# A2 - the biggest folders directly under /var (sort -h understands K/M/G)
sudo du -h --max-depth=1 /var 2>/dev/null | sort -h | tail -8
```
📸 Screenshot: `01-df-du.png`

**Note down:**
- Which filesystem shows the highest `Use%`, and how much is free on the one that holds your home folder?
- What are the three biggest folders directly under `/var`?

---

## Part B: ncdu on a real system folder (read-only!)

```bash
# B1 - -r = read-only (no deleting), -x = stay on one filesystem (don't wander into other mounts)
sudo ncdu -r -x /var/log
```
Inside ncdu (wait for the scan to finish first):
- `↑` / `↓` move, `Enter` or `→` opens a folder, `←` goes back up
- `s` sort by size, `n` sort by name, `g` toggle the bar graph / percentage view
- `i` shows details about the selected item, `?` shows help, **`q` quits**

📸 Screenshot: `02-ncdu-var-log.png` (take it while ncdu is open, with the biggest items visible)

**Note down:**
- What is the biggest item in `/var/log`? If it's a log file, would a `logrotate` rule from Day 07 apply to it?
- Do you see any `.gz` files, or numbered files like `.1`? What does that tell you about whether rotation is working?
- If Day 08's auditd is installed, how big is `/var/log/audit` compared to the rest?

---

## Part C: build a test folder and clean it up with ncdu

```bash
# C1 - a lab folder with files of different sizes
mkdir -p ~/ncdu-lab/{big,medium,small}
dd if=/dev/zero of=~/ncdu-lab/big/huge.bin bs=1M count=50 status=none
dd if=/dev/zero of=~/ncdu-lab/medium/mid.bin bs=1M count=10 status=none
for i in $(seq 1 200); do echo "tiny file $i" > ~/ncdu-lab/small/file$i.txt; done

# C2 - explore it
ncdu ~/ncdu-lab
```
Inside ncdu: check the ordering matches what you made, open `small/` (200 files, tiny total), then go back, put the cursor on `big/huge.bin` and press **`d`** to delete it (it asks you to confirm; this is the ONE place deleting is allowed today). Quit with `q` and check:
```bash
du -sh ~/ncdu-lab
```
📸 Screenshot: `03-ncdu-lab.png`

**Note down:**
- Which folder was biggest, and why is `small/` with 200 files barely visible in size?
- How much did `du -sh ~/ncdu-lab` drop after deleting `huge.bin`?

**Bonus (optional): scan as root, view as yourself.** ncdu can save a scan to a file and open it later:
```bash
sudo ncdu -r -x -o /tmp/ncdu-var.json /var
ncdu -f /tmp/ncdu-var.json          # opens the saved scan, no root needed, no re-scan
```

---

## Part D: the disk-space mystery (connects to Day 02 lsof)

```bash
# D1 - a 100 MB file, held open by a background process (sleep with the file open on stdin)
dd if=/dev/zero of=~/ncdu-lab/big.bin bs=1M count=100 status=none
sleep 600 < ~/ncdu-lab/big.bin &
HOLDER=$!
df -h ~ | tail -1                    # note the "Used" value BEFORE deleting

# D2 - delete the file while the process still has it open
rm ~/ncdu-lab/big.bin
ls ~/ncdu-lab/                       # big.bin is gone from the folder...
df -h ~ | tail -1                    # ...but is the space actually freed?

# D3 - find the ghost (Day 02's lsof trick)
sudo lsof +L1 | grep big.bin         # +L1 = open files with link count below 1, i.e. deleted
ls -l /proc/$HOLDER/fd | grep big.bin    # shows "(deleted)"

# D4 - let go of the file and watch the space come back
kill $HOLDER
sleep 1
df -h ~ | tail -1                    # Used should drop by ~100 MB now

# D5 - clean up
rm -rf ~/ncdu-lab /tmp/ncdu-var.json
```
📸 Screenshot: `04-deleted-open-trap.png`

**Note down:**
- What was `Used` before `rm`, right after `rm` (while the process still held the file), and after `kill`?
- Would `ncdu ~/ncdu-lab` have shown `big.bin` after the `rm`? Why not, and which tool could still find it?
- Connect it to Day 07: how does `copytruncate` (or `postrotate` + reopen) prevent this exact situation with a real log file?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `Command.txt`, and help you write `Notes.txt`.
