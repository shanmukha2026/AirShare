# 📡 AirShare

**Serverless · Peer-to-Peer · Local File Transfer**

AirShare is a cross-platform, serverless, peer-to-peer local file transfer application — similar to Apple AirDrop — that lets two devices on the same Wi-Fi network discover each other automatically and transfer files of any size directly, without any internet connection, cloud storage, or server infrastructure.

---

## 🌍 The Problem

Sharing files between devices today is unnecessarily complex:

| Method | Issue |
|---|---|
| ☁️ Cloud uploads (Drive, WhatsApp) | File round-trips through a remote server, wasting time and bandwidth for devices sitting right next to each other |
| 🔌 USB cables | Requires physical connectors, drivers, and compatible ports |
| 🍎 AirDrop | Apple-only |
| 📶 Bluetooth | Extremely slow — typically under 3 MB/s |

**AirShare** transfers files directly at local Wi-Fi speed (30–200+ MB/s) with zero internet dependency, zero account logins, and zero cost — across Android and Windows simultaneously.

---

## ✨ How It Looks to the User

Open AirShare on your laptop — a dark radar screen appears with a rotating scan line. Your phone shows up as a floating node within 2–3 seconds. Tap the node, pick a file, and the transfer begins instantly. On the receiving device, an Accept/Reject dialog pops up — tap Accept, and the file lands in your Downloads folder at full Wi-Fi speed.

---

## 📸 Screenshots

<table>
  <tr>
    <th align="center">📱 Android — Incoming File</th>
    <th align="center">🖥️ Windows — Peer Discovered</th>
  </tr>
  <tr>
    <td align="center">
      <img src="PASTE_ANDROID_INCOMING_URL_HERE" width="260"/>
    </td>
    <td align="center">
      <img src="PASTE_WINDOWS_PEER_URL_HERE" width="480"/>
    </td>
  </tr>
  <tr>
    <th align="center">🖥️ Windows — Transfer Complete</th>
    <th align="center">📱 Android — Transfer Panel</th>
  </tr>
  <tr>
    <td align="center">
      <img src="PASTE_WINDOWS_COMPLETE_URL_HERE" width="480"/>
    </td>
    <td align="center">
      <img src="PASTE_ANDROID_TRANSFER_URL_HERE" width="260"/>
    </td>
  </tr>
</table>

---

## ⚙️ How It Works

### Phase 1 — Device Discovery (UDP Broadcasting)
- App binds to **UDP port 53530**
- Broadcasts a small JSON packet (~200 bytes) every 2 seconds to `255.255.255.255`
- Every AirShare device on the same Wi-Fi hears it and appears on the radar
- The packet contains the device's name, unique ID, local IP, and the TCP port to connect to

### Phase 2 — File Transfer (TCP Streaming)
- Tapping a peer + selecting a file opens a direct **TCP connection**
- Sender connects to the receiver's IP on port `53531` and sends a JSON header (filename, size)
- Receiver shows an Accept/Reject dialog
- On accept, the file streams in binary chunks straight to disk — with **backpressure control** so large files never overflow memory

### Phase 3 — State Management (Riverpod)
- Peer lists, transfer progress, and speeds are managed with **Riverpod StateNotifiers**
- Only the affected UI (e.g. one transfer card) rebuilds on state change — keeping the UI at a smooth 60fps

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter & Dart** | Single codebase compiled natively to Android, Windows, iOS, and macOS |
| **dart:io — RawDatagramSocket** | UDP discovery layer; broadcasts device presence every 2s |
| **dart:io — ServerSocket / Socket** | TCP transfer engine; streams file chunks directly to disk without loading the full file into memory |
| **flutter_riverpod** | Type-safe, testable state management for peers and transfers |
| **CustomPainter (Canvas API)** | GPU-accelerated radar animation using sweep gradients and trigonometry |
| **network_info_plus** | Resolves the device's local IP for embedding in broadcast packets |
| **file_picker** | Native OS file picker on each platform |
| **path_provider** | Resolves the correct platform-specific save directory (Downloads) |

---

## 📊 Capabilities & Limitations

| Capability | Detail |
|---|---|
| Max file size | Theoretically unlimited — streamed in chunks directly to disk |
| Transfer speed | 30–100 MB/s on Wi-Fi 5, up to 200 MB/s+ on Wi-Fi 6 |
| Network requirement | Same Wi-Fi router / LAN — **no internet required** |
| Platforms | Android, Windows (any platform Flutter supports) |
| Concurrent transfers | Multiple, tracked in state, limited only by bandwidth |
| File types | Any — documents, videos, APKs, ZIPs, images, etc. |
| Security | Explicit Accept/Reject consent required; **not encrypted in transit** |
| Battery / background usage | Zero — all networking stops when the app is closed |
| Infrastructure cost | **$0.00/month** — no servers, no cloud, no database |

### ⚠️ Known Limitations
1. **No encryption in transit** — data travels as raw bytes (TLS wrapping planned)
2. **Same subnet only** — cannot discover devices across different routers/VLANs (mDNS could extend this)
3. **No resume on failure** — interrupted transfers restart from scratch
4. **No sender-side acknowledgement** — sender isn't notified once the receiver saves the file

---

## 🚀 Roadmap

- [ ] End-to-end encryption (TLS over TCP socket)
- [ ] Resumable transfers (byte-offset tracking)
- [ ] Multi-file & folder transfer (on-the-fly ZIP)
- [ ] mDNS-based discovery for more reliable peer detection across complex networks

---

## 📥 Getting Started

```bash
# Clone the repo
git clone https://github.com/shanmukha2026/AirShare.git
cd AirShare

# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d <android-device-id>
