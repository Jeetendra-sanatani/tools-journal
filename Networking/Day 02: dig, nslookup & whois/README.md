# 🔎 Networking Day 02: dig, nslookup & whois

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_02%2F15-blue?style=for-the-badge" alt="Day 02"/>
  <img src="https://img.shields.io/badge/tools-dig_%7C_nslookup_%7C_whois-orange?style=for-the-badge" alt="Tools"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 01 asked "can I reach it?" Day 02 asks "who is it, and how did my machine find its address in the first place?" DNS and ownership lookups. 🔎

---

## 🏆 Day 01 Recap — Challenge Solutions

**Challenge 1 (DNS or Connectivity?):** DNS was broken, not connectivity — ping by IP worked, ping by name failed. First file to check: `/etc/resolv.conf`.

**Challenge 2 (The TTL Hint):** `ttl=64` suggests a Linux-based system, `ttl=128` suggests Windows or a device with that default. Not fully trustworthy because the value also depends on how many hops already passed.

**Challenge 3 (The Scary Hop):** Loss showing up only at the final destination hop (not a hop in the middle) usually means the destination is rate-limiting ICMP, not a real network problem.

---

## 🎯 Mission Briefing

Before `ping google.com` even sends a packet, something has to turn `google.com` into an IP address. That something is DNS. Today's tools let you query DNS directly, choose which DNS server to ask, and find out who actually owns a domain or IP block.

```
🔎 MISSION: Query DNS & Ownership Directly
──────────────────────────────────────────
[x] Look up A, MX and NS records with dig
[x] Query a specific DNS server directly
[x] Do a reverse lookup (IP -> hostname)
[x] Compare dig vs nslookup
[x] Find out who owns a domain with whois
──────────────────────────────────────────
STATUS: Networking Day 02 — Done
```

---

## ⚡ Quick Theory

**dig** is the modern, detailed DNS lookup tool. A plain `dig google.com` returns a lot of information (query time, server used, flags); adding `+short` strips it down to just the answer.

**Record types, in plain English:**
```
A      ->  domain name to IPv4 address (the most common lookup)
MX     ->  which mail servers handle email for this domain
NS     ->  which nameservers are authoritative for this domain
PTR    ->  the reverse of A: IP address to hostname
```

**Querying a specific server** (`dig @8.8.8.8 ...`) bypasses your machine's configured DNS resolver and asks that server directly. This is useful for comparing results — if your normal DNS and Google's `8.8.8.8` give different answers, something local might be misconfigured or caching stale data.

**Reverse lookup** (`dig -x <ip>`) runs the whole process backwards: given an IP, it asks "what hostname is this IP registered to?" Not every IP has a reverse record, so sometimes this comes back empty — that itself is informative.

**nslookup** does the same basic job as `dig` but with a simpler, more old-fashioned output format. It is older and considered semi-deprecated in favor of `dig`/`host`, but it is still available everywhere, including Windows, which is why it is worth knowing.

**whois** is a completely different kind of lookup: it doesn't resolve names to IPs, it tells you **who registered** a domain or **who owns** a block of IP addresses — registrar, creation date, expiry date, and abuse contact info.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`)*

### 🔍 dig — full lookup
```bash
$ dig google.com

; <<>> DiG 9.20.27-2-Debian <<>> google.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 35995
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; QUESTION SECTION:
;google.com.                   IN      A

;; ANSWER SECTION:
google.com.             5      IN      A       142.251.220.46

;; Query time: 32 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Wed Sep 30 17:05:15 IST 2026
;; MSG SIZE  rcvd: 55
```
My resolver is `127.0.0.53` — the local stub resolver that Kali/systemd-resolved uses by default, which then forwards to the real upstream DNS server.

### 🔍 dig — short output, different record types
```bash
$ dig google.com +short
142.251.220.46

$ dig google.com MX +short
10 smtp.google.com.

$ dig google.com NS +short
ns3.google.com.
ns4.google.com.
ns1.google.com.
ns2.google.com.
```
`google.com` has 4 authoritative nameservers, and mail is routed through `smtp.google.com` with priority `10`.

### 🔍 dig — specific DNS server and reverse lookup
```bash
$ dig @8.8.8.8 google.com +short
142.251.220.46

$ dig -x 8.8.8.8 +short
dns.google.
```
Querying Google's public DNS (`8.8.8.8`) directly gave the exact same IP as my default resolver — confirms there's no local DNS misconfiguration or stale cache. The reverse lookup on `8.8.8.8` itself resolves to `dns.google.`, which makes sense — that address is Google's own public DNS service.

### 🔍 nslookup
```bash
$ nslookup google.com
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
Name:   google.com
Address: 142.251.222.110
Name:   google.com
Address: 2404:6800:4009:810::200e

$ nslookup -type=MX google.com
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
google.com      mail exchanger = 10 smtp.google.com.

Authoritative answers can be found from:

$ nslookup google.com 8.8.8.8
Server:         8.8.8.8
Address:        8.8.8.8#53

Non-authoritative answer:
Name:   google.com
Address: 142.251.222.110
Name:   google.com
Address: 2404:6800:4009:810::200e
```
Interesting: `nslookup` returned `142.251.222.110` while `dig` returned `142.251.220.46` a few seconds earlier — both are valid, real Google IPs. Large services like Google answer from many different front-end servers, so getting a different (but still legitimate) IP on a second query is completely normal, not an error.

### 🔍 whois — domain ownership
```bash
$ whois google.com
   Domain Name: GOOGLE.COM
   Registry Domain ID: 2138514_DOMAIN_COM-VRSN
   Registrar WHOIS Server: whois.markmonitor.com
   Updated Date: 2019-09-09T15:39:04Z
   Creation Date: 1997-09-15T04:00:00Z
   Registry Expiry Date: 2028-09-14T04:00:00Z
   Registrar: MarkMonitor Inc.
   Registrar IANA ID: 292
   Registrar Abuse Contact Email: abusecomplaints@markmonitor.com
   Registrar Abuse Contact Phone: +1.2086851750
   Domain Status: clientDeleteProhibited ...
   Domain Status: clientTransferProhibited ...
   Domain Status: clientUpdateProhibited ...
   Name Server: NS1.GOOGLE.COM
   Name Server: NS2.GOOGLE.COM
   Name Server: NS3.GOOGLE.COM
   Name Server: NS4.GOOGLE.COM
   DNSSEC: unsigned
```
`google.com` was registered on **1997-09-15**, is registered through **MarkMonitor Inc.**, and every "client...Prohibited" status flag means the domain is locked against accidental transfer, update or deletion — standard protection for a high-value domain.

### 🔍 whois — IP ownership
> ⏳ **Pending.** `whois 8.8.8.9` output hasn't been captured yet. Once run, this section will show which organization (expected: Google) owns that IP block.
```bash
$ whois 8.8.8.9
[output to be added]
```

---

## 🧪 What I Actually Found

- [x] A record for `google.com`: `142.251.220.46` (dig) / `142.251.222.110` (nslookup) — both valid, different front-end servers
- [x] MX record: `10 smtp.google.com.`
- [x] NS records: `ns1`–`ns4.google.com.`
- [x] `dig @8.8.8.8` matched my default resolver's answer — no local DNS issue
- [x] Reverse lookup on `8.8.8.8` returned `dns.google.`
- [x] `google.com` registered via MarkMonitor Inc. on 1997-09-15
- [ ] IP ownership via `whois` — pending

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Record Type Roulette**
> You need to know where a domain's email actually gets delivered. Which record type do you query, and what does the number in front of the result (like `10` in `10 smtp.google.com.`) mean?

<details>
<summary>My answer</summary>

Query the MX record. The number is the **priority** — lower numbers are tried first. If a domain has multiple MX records (e.g. `10 mail1` and `20 mail2`), mail servers try the lowest-priority one first and fall back to higher numbers if it's unreachable.

</details>

> **🥊 Challenge 2: Same Domain, Different IP**
> `dig google.com +short` and `nslookup google.com` returned two DIFFERENT IP addresses for the same domain, seconds apart. Is this a problem?

<details>
<summary>My answer</summary>

No. Large services like Google run many front-end servers across the world, and DNS can legitimately return a different (but equally valid) IP on each query — this is normal load balancing, not an error or a misconfiguration.

</details>

> **🥊 Challenge 3: Locked Down**
> `whois google.com` showed multiple `Domain Status: client...Prohibited` flags. What do these actually protect against?

<details>
<summary>My answer</summary>

They prevent the domain from being deleted, transferred to another registrar, or having its core details updated without extra verification — standard protection against accidental or malicious changes to a high-value domain.

</details>

---

## 🧩 Quick Brain Check

1. What's the difference between what `dig` and `whois` each tell you?
2. Why would you query `@8.8.8.8` directly instead of just using your default DNS?
3. What does an MX record's priority number control?
4. Why might a reverse lookup (`dig -x`) sometimes return nothing at all?
5. Why is getting a different (but valid) IP from two separate DNS queries not automatically a red flag?

---

## 🐛 Errors / Gotchas I Hit

- My first two screenshots for `dig @8.8.8.8` and `dig -x` were accidentally the same image uploaded twice under different names — had to re-run and re-capture those two commands separately to get the real output.
- `nslookup` and `dig` returned two different (but both valid) IPs for `google.com` within seconds of each other — initially looked like an inconsistency, actually just normal DNS load balancing across Google's front-end servers.
- `whois 8.8.8.9` output is still pending — need to capture and add it.

---

## 🔐 Security Relevance

DNS and whois lookups are the very first step of reconnaissance in a penetration test: nameservers reveal infrastructure, MX records reveal the mail provider (useful for phishing simulations in authorized engagements), and whois reveals registrar and contact details. Defenders also use these tools to confirm their own domain's records are correct and to investigate suspicious domains.

---

## 🧠 Today's Takeaway

`dig` is the detailed, modern DNS tool; `nslookup` does the same job in an older, simpler format. Querying a specific server (`@8.8.8.8`) is how you rule out local DNS misconfiguration. And `whois` answers a completely different question than DNS tools — not "what's the IP?" but "who owns this?"

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 03: curl & wget**
