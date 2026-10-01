# 🌐 Networking Day 03: curl & wget

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_03%2F15-blue?style=for-the-badge" alt="Day 03"/>
  <img src="https://img.shields.io/badge/tools-curl_%7C_wget-orange?style=for-the-badge" alt="Tools"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 02 asked DNS "where is it?" Day 03 goes one layer up: once you have an address, what does the web server there actually say back? 🌐

---

## 🏆 Day 02 Recap — Challenge Solutions

**Challenge 1 (Record Type Roulette):** Query the MX record. The number in front (e.g. `10`) is the priority — lower numbers are tried first by mail servers.

**Challenge 2 (Same Domain, Different IP):** Not a problem. Large services run many front-end servers; getting a different, equally valid IP on separate queries is normal load balancing.

**Challenge 3 (Locked Down):** The `client...Prohibited` flags protect a domain from accidental or unauthorized deletion, transfer, or update.

---

## 🎯 Mission Briefing

DNS gets you an IP. `curl` and `wget` are what actually talk to the server at that IP over HTTP(S) — fetching pages, checking headers, downloading files, and revealing details about the server itself along the way.

```
🌐 MISSION: Talk to Web Servers Directly
──────────────────────────────────────────
[x] Fetch a page and inspect it from the terminal
[x] Check HTTP headers and status codes
[x] See a full request/response with verbose mode
[x] Follow redirects and save output to a file
[x] Find my own public IP
[x] Download a file with wget
──────────────────────────────────────────
STATUS: Networking Day 03 — Done
```

---

## ⚡ Quick Theory

**curl** prints the response straight to your terminal by default. Add `-I` to get only the headers (fast way to check if something is alive and what it returns), or `-v` to see the entire exchange: DNS resolution, TCP connection, the request sent, and the response received.

**HTTP headers reveal a lot about a server** — not just status codes, but the technology stack behind it:
```
Server: Microsoft-IIS/8.5        ->  running IIS, a Windows web server
X-Powered-By: ASP.NET             ->  built with ASP.NET
X-AspNet-Version: 2.0.50727        ->  specific framework version
```
This is exactly the kind of fingerprinting a pentester does in the recon phase — version numbers help identify known vulnerabilities for that specific stack.

**Redirects**: `curl -L` follows them automatically. Without `-L`, a redirect just shows up as a 301/302 response with no real body — you'd see the redirect itself, not the final destination.

**wget vs curl**, the practical difference: `curl` is built for flexibility (APIs, headers, scripting, piping); `wget` is built for straightforward downloading — it shows a progress bar by default and can resume interrupted downloads with `-c`.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`. Target: `testaspnet.vulnweb.com` — Acunetix's publicly available, intentionally vulnerable test site, used here instead of example.com so the headers would actually reveal something.)*

### 📄 curl — basic request and headers
```bash
$ curl http://testaspnet.vulnweb.com/
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
  <HEAD>
    <title>acublog news</title>
    ...
  <TABLE id="Table1" ...>
    <TD ...><a href="https://www.acunetix.com/">...</a></TD>
    <TD ...>Test Website for <a href="https://www.acunetix.com/vulnerability-scanner/">Acunetix Web Vulnerability Scanner</a></TD>
  </TABLE>
```

```bash
$ curl -I http://testaspnet.vulnweb.com/
HTTP/1.1 200 OK
Cache-Control: private
Content-Length: 14110
Content-Type: text/html; charset=utf-8
Server: Microsoft-IIS/8.5
X-AspNet-Version: 2.0.50727
Set-Cookie: ASP.NET_SessionId=swh5nofdgwrjlnid4ehov155; path=/; HttpOnly
X-Powered-By: ASP.NET
Date: Thu, 01 Oct 2026 04:16:46 GMT
```
Status `200 OK`. The headers alone already reveal it's a **Windows IIS 8.5 server running ASP.NET 2.0** — useful recon info without even looking at the page content.

### 🔬 curl — verbose mode
```bash
$ curl -v http://testaspnet.vulnweb.com/
* Host testaspnet.vulnweb.com:80 was resolved.
* IPv4: 44.238.29.244
* Trying 44.238.29.244:80...
* Established connection to testaspnet.vulnweb.com (44.238.29.244) port 80 from 192.168.80.136 port 52772
* using HTTP/1.x
> GET / HTTP/1.1
> Host: testaspnet.vulnweb.com
> User-Agent: curl/8.21.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< Server: Microsoft-IIS/8.5
< Set-Cookie: ASP.NET_SessionId=2huhli55sjpznn55ujdin3et; path=/; HttpOnly
< Content-Length: 14110
<
<!DOCTYPE HTML PUBLIC ...
```
`-v` shows every step before the data even arrives: DNS resolved to `44.238.29.244`, TCP connected from my own `192.168.80.136:52772`, the exact request line (`GET / HTTP/1.1`) sent with lines prefixed `>`, then the response headers prefixed `<`, then finally the body. Note a different `ASP.NET_SessionId` cookie than the `-I` request — every new request gets a fresh session.

### 🔀 curl — following redirects, saving to file
```bash
$ curl -L https://httpbin.org/redirect/1
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.org",
    "User-Agent": "curl/8.21.0",
    "X-Amzn-Trace-Id": "Root=1-6abde015-6aabd18357a2139d336dc9e4"
  },
  "origin": "103.116.179.241",
  "url": "https://httpbin.org/get"
}

$ curl -L http://testaspnet.vulnweb.com -o curl-output.html
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 14111  100 14111    0     0  17161      0 --:--:-- --:--:-- --:--:--

$ ls -lh curl-output.html
-rw-rw-r-- 1 ruin ruin 14K Oct  1 09:52 curl-output.html
```
`httpbin.org/redirect/1` redirected to `httpbin.org/get`, and `curl -L` followed it automatically, landing on the final JSON response. `httpbin` even echoed back my public IP in the `"origin"` field: `103.116.179.241` — matches the IP found independently below. The `-o` flag saved the second request's output to a real 14K file.

### 🌍 My public IP
```bash
$ curl https://api.ipify.org
103.116.179.241

$ echo "Public IP: $(curl -s https://api.ipify.org)"
Public IP: 103.116.179.241
```
Matches the `origin` field httpbin.org reported above — confirms this is genuinely my outward-facing IP, not a fluke.

### 📥 wget — downloading a file
```bash
$ wget http://testaspnet.vulnweb.com/
--2026-10-01 09:55:27--  http://testaspnet.vulnweb.com/
Resolving testaspnet.vulnweb.com (testaspnet.vulnweb.com)... 44.238.29.244
Connecting to testaspnet.vulnweb.com (testaspnet.vulnweb.com)|44.238.29.244|:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 14111 (14K) [text/html]
Saving to: 'index.html'

index.html          100%[===================>]  13.78K  51.0KB/s   in 0.3s

2026-10-01 09:55:28 (51.0 KB/s) - 'index.html' saved [14111/14111]

$ ls -lh index.html
-rw-rw-r-- 1 ruin ruin 14K Oct  1 09:55 index.html
```
Compared to `curl`'s default (prints to screen), `wget`'s default behavior is the opposite: it shows a live progress bar (percentage, speed, ETA) and saves straight to a file (`index.html`, matching the server's filename) without needing `-o`.

> ⏳ **Skipped:** the large-file speed-limited download test (C2, `speed.hetzner.de/100MB.bin`) was skipped this round — it was marked optional in the lab to save time, and the core wget behavior was already clearly shown above.

---

## 🧪 What I Actually Found

- [x] `curl` default: prints HTML body straight to the terminal
- [x] `curl -I`: status `200 OK`, revealed `Microsoft-IIS/8.5` + `ASP.NET` stack
- [x] `curl -v`: full handshake visible — DNS, TCP connect, request/response, each with its own session cookie
- [x] `curl -L`: followed a real redirect (`/redirect/1` → `/get`) and confirmed my public IP via `httpbin.org`
- [x] Public IP confirmed independently via `api.ipify.org`: `103.116.179.241`
- [x] `wget`: downloaded with a visible progress bar and saved directly to a file
- [ ] Speed-limited large download test — skipped (optional)

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Headers as Recon**
> Just from `curl -I`'s output, list every piece of technology information you can determine about the server, without looking at the HTML.

<details>
<summary>My answer</summary>

From the headers alone: it's running **Microsoft IIS 8.5** (`Server:`), built with **ASP.NET** (`X-Powered-By:`), specifically **version 2.0.50727** of the .NET Framework (`X-AspNet-Version:`), and it issues session cookies (`Set-Cookie: ASP.NET_SessionId=...`). That's a full technology fingerprint without ever opening the page.

</details>

> **🥊 Challenge 2: Session Cookie Mismatch**
> The `-I` request and the `-v` request to the same URL returned two DIFFERENT `ASP.NET_SessionId` cookie values. Is this a bug?

<details>
<summary>My answer</summary>

No. Each separate HTTP request with no stored cookie is treated by the server as a brand new visitor, so IIS issues a fresh session ID every time. `curl` doesn't persist cookies between separate invocations unless you explicitly tell it to (with `-c`/`-b` cookie jar flags), so this is expected behavior, not an error.

</details>

> **🥊 Challenge 3: curl vs wget, Pick One**
> You need to script a nightly job that checks if a company's homepage returns a 200 status code and alerts if not. Which tool fits better, and what's the one-line command?

<details>
<summary>My answer</summary>

`curl` fits better here, since it's built for scripting and returning just a status code cleanly:
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://example.com
```
`wget` is more oriented toward actually saving files, which isn't needed for a simple status check.

</details>

---

## 🧩 Quick Brain Check

1. What's the practical difference between `curl -I` and `curl -v`?
2. Why did two separate requests to the same URL return two different session cookies?
3. What does `curl -L` do that plain `curl` doesn't?
4. Name two pieces of server technology info you can learn just from HTTP headers.
5. If you needed to resume a large interrupted download, which tool and flag would you reach for?

---

## 🐛 Errors / Gotchas I Hit

- Used `testaspnet.vulnweb.com` and `httpbin.org` instead of `example.com` from the lab sheet — both are legitimate public test services (Acunetix's own vulnerable test site, and httpbin's request-echoing service), so results were actually more informative than a static example page would have been.
- Skipped the large speed-limited download (C2) since it was marked optional — the core wget behavior was already fully demonstrated by the smaller download.
- Every fresh request without a saved cookie jar gets a new session ID from IIS — not an error, just how stateless HTTP requests work without cookie persistence.

---

## 🔐 Security Relevance

HTTP headers are a goldmine during recon: `Server`, `X-Powered-By`, and framework version headers (like `X-AspNet-Version` here) let an attacker (or a defender auditing their own systems) immediately narrow down known vulnerabilities for that specific stack and version. This is exactly why security-conscious configurations often strip or obscure these headers in production.

---

## 🧠 Today's Takeaway

`curl` is the flexible, scriptable tool — headers only (`-I`), full detail (`-v`), follow redirects (`-L`), save output (`-o`). `wget` is the straightforward downloader with a progress bar by default. And HTTP headers alone — before even reading a page's content — can reveal the entire technology stack behind a server.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 04: nmap part 1 — host discovery & basic scans**
