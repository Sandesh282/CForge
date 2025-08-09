# CForge — Real-Time Codeforces Companion

CForge is a sleek **iOS** app for competitive programmers that delivers **live contests, problem browsing, and profile stats** straight from the **Codeforces REST API** — all in a polished **SwiftUI** experience.

Whether you're prepping for your next competition or tracking your rank climb, CForge brings the Codeforces ecosystem to your fingertips.

---

## 📸 Screenshots

| Home Screen | Contest List | Problem Browser | Profile Stats |
|-------------|--------------|-----------------|---------------|
| ![Home Screen](![Uploading IMG_1103.PNG…]()
) | ![Contest List](![Uploading IMG_1104.PNG…]()
) | ![Problem Browser](![Uploading IMG_1105.PNG…]()
) | ![Profile Stats](![Uploading IMG_1107.PNG…]()
) |

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

