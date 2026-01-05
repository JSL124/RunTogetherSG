# 🏃 RunTogetherSG

**RunTogetherSG** is a Flutter-based running community app designed to help runners create, discover, and join group running events in Singapore.

The app focuses on making running more social and sustainable by combining **map-based events**, **real-time chat**, and **simple event management**.

---

## ✨ Features

- 🗺️ **Map-based Running Events**
  - View nearby running events on Google Maps
  - Clear meeting points and event locations

- 🏃‍♂️ **Create & Join Runs**
  - Host your own running events
  - Join or leave events easily
  - Participant limits and difficulty levels

- 💬 **Real-time Event Chat**
  - Group chat for each running event
  - System messages for join/leave updates
  - Message history synced with Firestore

- 👤 **User Authentication**
  - Email & password authentication using Firebase Auth
  - Secure login and logout

- 🏅 **Runner Level System**
  - Gamified running levels based on participation count
  - Visual level indicators with icons and colors

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
- **Maps**: Google Maps API
- **Architecture**: Stream-based real-time updates

---

## 📱 Screens (Coming Soon)

- Map View
- Event Chat
- Profile & Runner Levels

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK
- Firebase project
- Google Maps API key

### Installation

```bash
git clone https://github.com/your-username/RunTogetherSG.git
cd RunTogetherSG
flutter pub get
flutter run
