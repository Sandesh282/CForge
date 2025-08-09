# CForge — Real-Time Codeforces Companion

CForge is a sleek **iOS** app for competitive programmers that delivers **live contests, problem browsing, and profile stats** straight from the **Codeforces REST API** — all in a polished **SwiftUI** experience.

Whether you're prepping for your next competition or tracking your rank climb, CForge brings the Codeforces ecosystem to your fingertips.

---

## 📸 Screenshots


<table>
<tr>
<td width="600" align="center"><b>⚡️ Splash Screen</b><br>
<img src="https://github.com/user-attachments/assets/f52319d9-ab45-4cbf-82fb-f8c25af5ff27" width="100%">
</td>
<td width="600" align="center"><b>🏠 Home View</b><br>
<img src="https://github.com/user-attachments/assets/285b0bf0-bdad-4e75-9b4f-5fb9a8ed0a6f" width="100%">
</td>
<td width="600" align="center"><b>🏆 Contest View</b><br>
<img src="https://github.com/user-attachments/assets/CONTEST_VIEW_PLACEHOLDER" width="100%">
</td>
<td width="600" align="center"><b>📜 Problem List View</b><br>
<img src="https://github.com/user-attachments/assets/468b3000-50dd-4390-88b4-b8ad5c2d0509" width="100%">
</td>
</tr>
<tr>
<td width="600" align="center"><b>👤 Profile View</b><br>
<img src="https://github.com/user-attachments/assets/3053cce3-d429-4db9-8e25-cb4cc3829f31" width="100%">
</td>
<td width="600"></td>
<td width="600"></td>
</tr>
</table>

---

## ✨ Features

- 📅 **Live Contest Tracking** — Get a real-time list of upcoming and ongoing contests.  
- 🔍 **Problem Explorer** — Browse, search, and filter problems by difficulty and tags.  
- 📊 **Profile Insights** — Check user ratings, ranks, and historical trends.  
- ⚡ **Smooth Animations** — SwiftUI + Combine for responsive and modern UI.

---

## 🛠 Tech Stack

| Layer         | Tools & Technologies                                             |
|---------------|------------------------------------------------------------------|
| **UI**        | SwiftUI, Combine                                                 |
| **Networking**| URLSession, JSONDecoder                                          |
| **Image Loading** | SDWebImage                                                   |
| **API**       | Codeforces REST API (`/contest.list`, `/user.info`, `/problemset.problems`) |
| **IDE**       | Xcode                                                            |
| **Platform**  | iOS                                                              |

---

## ⚙️ Installation

1. Clone the repository:  
   ```bash
   git clone https://github.com/username/CForge.git
   cd CForge
    ```
2. Open in Xcode:
   ```bash
   open CForge.xcodeproj
   ```
3. Run on simulator or a conneccted iOS device.

## 🌐 API Reference
CForge uses the Codeforces REST API.

Endpoints in use:

/contest.list — Fetches upcoming and ongoing contests.

/user.info — Retrieves profile information and ratings.

/problemset.problems — Provides the full problem set with tags and ratings.

## Credits

- **Codeforces REST API** — for contest, problemset, and profile data.  
- **SwiftUI & Combine** — Apple frameworks for building modern UIs.  
- **Xcode** — IDE used for development.

