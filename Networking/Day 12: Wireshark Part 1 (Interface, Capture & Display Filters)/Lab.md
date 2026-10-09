# 🧪 Lab Sheet — Networking Day 12: Wireshark Part 1 (Interface, Capture & Display Filters)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Only capture traffic on your own machine and your own interfaces (loopback `lo` and your own `eth0`).**

**Shortcut:** if you already have a loopback capture of your local web traffic (for example `basic_capture.pcapng` from your earlier session), open it with File → Open and reuse it for Parts B and C instead of capturing again.

---

## Step 0: Start the local web server and Wireshark

```bash
# Terminal 1 - local web server, leave it running
mkdir -p ~/tcpdump-lab && cd ~/tcpdump-lab
echo "wireshark practice" > index.html
python3 -m http.server 8080
```
```bash
# Terminal 2 - launch Wireshark
wireshark &
```
If capturing on an interface gives a permission error, close Wireshark and start it with `sudo wireshark &`. The permanent fix is `sudo usermod -aG wireshark $USER`, then log out and back in.

---

## Part A: your first capture on loopback

1. On Wireshark's start screen, double-click **Loopback: lo**. The capture starts.
2. In Terminal 3, send three requests (run this line 3 times):
```bash
curl -s http://127.0.0.1:8080/ > /dev/null
```
3. Stop the capture with the red square button, then File → Save As → `basic_capture.pcapng`.

📸 Screenshot: `01-first-capture.png` (the whole Wireshark window with the capture visible)

**Note down:**
- Wireshark shows three panes (packet list, packet details, packet bytes). What does each one show?
- How many packets in total (status bar) for 3 curl requests? How many per single request?

---

## Part B: display filters

Type each filter into the filter bar and press Enter. The bar turns green when the filter is valid and red when it isn't. After each one, note the **Displayed: X of Y** count in the status bar.

```text
B1   tcp.port == 8080
B2   http
B3   http && tcp.port == 8080
B4   tcp.flags.syn == 1
B5   tcp.flags.syn == 1 && tcp.flags.ack == 0
B6   ip.addr == 127.0.0.1
```

📸 Screenshot: `02-display-filters.png` (B3 is a good one to show; a second shot of B4 or B5 is welcome)

**Note down:**
- How many packets were displayed for each of B1 to B6?
- B4 and B5 give different counts. Why? (Hint: think about the TCP handshake you read on Day 10.)
- On Day 11 you used tcpdump filters, which are *capture* filters. What's the difference between a capture filter and a display filter in terms of **when** each one applies?

---

## Part C: reading a single packet

Set the display filter to `http`, then click packets and expand the sections in the packet details pane.

1. Click the `GET / HTTP/1.1` packet and expand: Frame, Ethernet II, Internet Protocol, Transmission Control Protocol, Hypertext Transfer Protocol.
2. Click the `HTTP/1.0 200 OK` packet and expand its Hypertext Transfer Protocol section.

📸 Screenshot: `03-packet-details.png` (one shot of the request, one of the response)

**Note down:**
- From the request: the `Host`, the `User-Agent`, the source port and the destination port.
- From the response: the `Server` header, `Content-Length`, `Request in frame` and `Time since request`.
- Which layer (Ethernet, IP, TCP or HTTP) holds each of those fields?

---

## Part D: capture on your real interface

1. Close the current file (File → Close), then double-click **eth0** on the start screen to start capturing.
2. In Terminal 3:
```bash
ping -c 4 1.1.1.1
dig google.com
```
3. Stop the capture and apply the display filter `icmp || dns`.
4. Clear the filter and scroll through everything else that was captured.

📸 Screenshot: `04-eth0-icmp-dns.png`

**Note down:**
- How many ICMP packets did 4 pings produce, and why that number?
- Which DNS packets did `dig` produce (query and response)?
- What else showed up once you cleared the filter? Compare it with the "idle interface" background traffic you saw on Day 10.

---

## When you're done

Send me:
1. The screenshots (or a description of what each filter showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
