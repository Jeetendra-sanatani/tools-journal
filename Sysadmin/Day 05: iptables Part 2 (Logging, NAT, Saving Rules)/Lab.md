# 🧪 Lab Sheet — Sysadmin Day 05: iptables Part 2 (Logging, NAT, Saving Rules)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Do Day 04 first if you haven't** — this builds directly on the `filter` table basics (ACCEPT, DROP, rule order) from that day.

---

## ⚠️ Read this before Part D specifically

Part D builds a small "base firewall" script with a default-DROP policy. A default-DROP policy that doesn't explicitly allow your own SSH session can lock you out instantly, with no warning, the moment it's applied. Day 04's warning still applies: console access to your VM, not just SSH, before trying this. The lab script below allows loopback and established connections FIRST, specifically to avoid this — read it before running it, don't just paste it.

---

## Step 0: Pick up where Day 04 left off
```bash
sudo iptables -L -v -n     # should be empty/default if you cleaned up properly on Day 04
```

---

## Part A: logging — see a DROP happen in real time

```bash
# A1 - log ICMP, then drop it (LOG does NOT stop the packet, it just records it - the DROP after is separate)
sudo iptables -A INPUT -p icmp -j LOG --log-prefix "ICMP-DROPPED: "
sudo iptables -A INPUT -p icmp -j DROP

# A2 - generate some ICMP traffic to log
ping -c 3 127.0.0.1

# A3 - find the log entries (location varies by system)
sudo journalctl -k --since "2 min ago" | grep ICMP-DROPPED
# or, if that's empty:
sudo dmesg | grep ICMP-DROPPED
```
📸 Screenshot: `01-logging.png`

**Note down:**
- Did the LOG rule by itself block anything, or did you still need the separate DROP rule after it? (Re-read the theory if unsure.)
- What information does one log line contain (source IP, protocol, interface...)?

---

## Part B: NAT table — MASQUERADE (read, don't necessarily apply)

NAT only matters if this machine is routing traffic for OTHER machines (acting as a gateway) — on a single Kali VM with no routed clients behind it, there's nothing for it to actually DO, but it's worth seeing the rule and understanding it.

```bash
# B1 - view the (probably empty) nat table
sudo iptables -t nat -L -v -n

# B2 - the rule a machine acting as an internet gateway would add (read only, don't need to apply it
#      unless you have a second VM set up to route for)
echo 'sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'

# B3 - if you DO want to try applying it safely (it's harmless with nothing behind it):
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -L -v -n
sudo iptables -t nat -F    # clean up right after
```
📸 Screenshot: `02-nat.png`

**Note down:**
- In one sentence, what does MASQUERADE actually DO to a packet's source address?
- Why would this rule go in `POSTROUTING` specifically, rather than `PREROUTING`?

---

## Part C: saving and restoring rules

```bash
# C1 - add one harmless, easy-to-recognize test rule
sudo iptables -A INPUT -p tcp --dport 9999 -j ACCEPT

# C2 - save the CURRENT rules to a file
sudo iptables-save > ~/iptables-backup.rules
cat ~/iptables-backup.rules | grep 9999

# C3 - flush everything (simulating "something went wrong, rules are gone")
sudo iptables -F

# C4 - confirm it's really gone
sudo iptables -L -v -n

# C5 - restore from the file
sudo iptables-restore < ~/iptables-backup.rules

# C6 - confirm the test rule is back
sudo iptables -L -v -n | grep 9999
```
📸 Screenshot: `03-save-restore.png`

**Note down:**
- Without `iptables-save`, what happens to all your rules on a simple reboot?
- What's the difference between `iptables-save`/`iptables-restore` (manual, one-time) and a persistence package like `iptables-persistent` (automatic, on every boot)? (You don't need to install it — just answer from what you can reason out or look up.)

---

## Part D: a small base firewall (read carefully first)

```bash
sudo iptables -F
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

sudo iptables -L -v -n --line-numbers
```
Test that you can STILL reach this machine over SSH from another terminal/device (if you have one set up), or at minimum confirm loopback and your own shell still work normally:
```bash
ping -c 3 127.0.0.1
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/ 2>&1
```
📸 Screenshot: `04-base-firewall.png`

**Note down:**
- Why does the `ESTABLISHED,RELATED` rule come BEFORE the SSH-specific rule, and would swapping their order actually break anything? (Think about rule order from Day 04.)
- With this policy set, what happens to a connection attempt on a port that ISN'T 22 and isn't already established? (Try it: `curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://127.0.0.1:8080/` if nothing's listening there, or pick a port you know is closed.)
- Clean up afterward: `sudo iptables -F && sudo iptables -P INPUT ACCEPT && sudo iptables -P FORWARD ACCEPT`

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird — especially if Part D did anything unexpected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
