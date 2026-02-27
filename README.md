# Joe's Corner Billing App

A Flutter Android billing app with a Node.js + PostgreSQL backend for Joe's Corner.

## Project Structure

```
joebill/
├── backend/          Node.js + Express API
└── flutter_app/      Flutter Android app
```

---

## Backend Setup

### Prerequisites
- Node.js 18+
- PostgreSQL 14+

### 1. Create the database

```bash
psql -U postgres -c "CREATE DATABASE joebill;"
```

### 2. Configure environment

```bash
cd backend
cp .env.example .env
# Edit .env with your DB credentials
```

### 3. Run migrations (creates tables + seeds default data)

```bash
npm run migrate
```

### 4. Start the server

```bash
npm run dev        # development (auto-reload)
npm start          # production
```

Server runs on `http://0.0.0.0:3000`

### Default login
- **Username:** `admin`
- **Password:** `password`

> Change the admin password immediately after first login via Settings → Users.

---

## Flutter App Setup

### Prerequisites
- Flutter 3.19+
- Android SDK

### 1. Install dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Run on device/emulator

```bash
flutter run
```

### 3. Configure server URL

On the login screen, tap **Server settings** and enter your server's local IP:
```
http://192.168.1.x:3000
```

---

## Features

- **Live Tabs** — open customer tabs with running totals on the home screen
- **Add Items** — food, drinks, beverages with quantity controls
- **Game Timer** — start/stop timer for Pool, Snooker, Darts, Foosball; cost auto-calculated
- **Settle Bill** — Cash or UPI, generates PDF receipt, print or share via WhatsApp
- **Reports** — daily revenue, category breakdown, game breakdown, top items (admin only)
- **Settings** — add/edit/disable menu items, update rates, manage users (admin only)

## Game Rates (default)

| Game     | Rate        |
|----------|-------------|
| Pool     | ₹2.50/min   |
| Snooker  | ₹3.30/min   |
| Darts    | ₹1.50/min   |
| Foosball | ₹1.00/min   |

Rates can be updated anytime from Settings → Menu Items.
