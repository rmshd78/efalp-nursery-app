# EFALP Nurseries · Plant Management App

Internal stock and QR management app for **EFALP Nurseries** (Al Raheeb Nursery and Dhadna Nursery), for 3 roles:
Super Admin, Manager and Engineer.

**App address:** https://rmshd78.github.io/efalp-nursery-app/

- Dashboard, plant master search, add / edit / delete stock, size breakdown
- Photo reports from the phone, QR codes and printable QR labels
- Super Admin adds new fields, approves users and changes settings
- Live updates between users, activity log, Excel (CSV) export and full backup

## How it works

A static web app (HTML + JavaScript, no build step) hosted free on GitHub Pages. Data, logins and photos are in
**Supabase**. Row-level security in [`supabase/1_setup.sql`](supabase/1_setup.sql) means only approved staff can read or
change anything.

**No stock data is stored in this repository.** The initial data file (`2_data.sql`) is kept private and is
git-ignored. `config.js` contains only the Supabase project URL and the public *anon* key, which are safe to publish.

## Setup

See **[SETUP_GUIDE.md](SETUP_GUIDE.md)**.
