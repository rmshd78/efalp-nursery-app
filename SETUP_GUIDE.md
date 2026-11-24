# EFALP Nurseries – Plant Management App · Setup Guide

**Where things live**

| Part | Where | Cost |
|---|---|---|
| The app (web pages) | GitHub Pages, repository `rmshd78/efalp-nursery-app`: **https://rmshd78.github.io/efalp-nursery-app/** | Free |
| Database, logins and photos | **Supabase** (online Postgres database) | Free plan |

Everyone opens the same link from any site, on a phone or a PC. When one person adds, edits or deletes something,
the others see it within about 5 seconds. No Azure, IT or server is needed.

Setup takes about 15 minutes and has 5 steps.

---

## Step 1 · Create the Supabase project (3 min)

1. Go to **https://supabase.com** → **Start your project** → sign up (with your GitHub account or an email).
2. **New project**:
   - Name: `efalp-nursery`
   - Database password: create a strong one and **save it somewhere safe**
   - Region: pick the one closest to the UAE in the list
3. Wait about 1–2 minutes until the project is ready.

## Step 2 · Create the database (2 min)

1. In Supabase, open **SQL Editor** (left menu) → **New query**.
2. Open [`supabase/1_setup.sql`](supabase/1_setup.sql), copy **everything**, paste it, and press **Run**. You should see *Success*.
3. Your plant data is loaded later, from inside the app (step 5): you sign in, and the dashboard shows an
   **Import your stock data** button where you choose the file **EFALP_starting_data.json** (sent to you
   separately, not on GitHub, because it contains your stock quantities).

> Run `1_setup.sql` before anyone creates an account.

## Step 3 · Login settings (2 min)

1. **Authentication → URL Configuration**:
   - **Site URL:** `https://rmshd78.github.io/efalp-nursery-app/`
   - **Redirect URLs:** add the same address.

   This makes the "confirm your email" and "reset password" links open the app.
2. **Authentication → Sign In / Providers → Email**: leave it **enabled**. Keep **Confirm email** turned on
   (recommended).

## Step 4 · Connect the app and turn on GitHub Pages (3 min)

1. In Supabase, open **Project Settings → API Keys** (or the **Connect** button at the top) and copy:
   - the **Project URL**, like `https://abcdefgh.supabase.co`
   - the **anon / public** key (or the **publishable** key, which starts with `sb_publishable_`)
2. On GitHub, open `config.js` → pencil icon ✏️ → paste the two values → **Commit changes**.
3. Turn on the website: repository **Settings → Pages** → *Source*: **Deploy from a branch** → Branch **main**,
   folder **/ (root)** → **Save**. After 1–2 minutes the app is live at https://rmshd78.github.io/efalp-nursery-app/

> ⚠️ Use only the **anon / publishable** key. **Never** put the `service_role` or `secret` key in config.js.
> The anon key is safe to be public because the database itself only lets approved, signed-in staff read or change data.

## Step 5 · Accounts

1. **You first:** open https://rmshd78.github.io/efalp-nursery-app/ → **Create account** → confirm the email →
   sign in. **The first account automatically becomes Super Admin.** On the dashboard, press **Choose file…** under
   *Import your stock data* and pick **EFALP_starting_data.json**. The 354 stock lines load in a few seconds.
2. Send the link to your manager and the engineer. They press **Create account** and confirm their email.
3. In the app, open **Users**. They appear under *Waiting for approval*. Press **Approve as Engineer** or **as Manager**.

---

## What each role can do

The database enforces these rules, not just the app.

| Action | Super Admin | Manager | Engineer | Viewer |
|---|:-:|:-:|:-:|:-:|
| Dashboard, Plant Master search, QR codes, labels, export | ✓ | ✓ | ✓ | ✓ |
| Add & edit plants, update stock quantities | ✓ | ✓ | ✓ | – |
| Add photo reports (and delete their own) | ✓ | ✓ | ✓ | – |
| Delete plants and any report | ✓ | ✓ | – | – |
| Activity log | ✓ | ✓ | – | – |
| Add / edit / delete **fields** | ✓ | – | – | – |
| Approve users, change roles, settings | ✓ | – | – | – |

> Databases set up before the Viewer role existed: run [`supabase/2_add_viewer_role.sql`](supabase/2_add_viewer_role.sql) once in the SQL Editor.

## Main features

- **Dashboard:** total plants, per-nursery totals, species, stock value (from unit prices), plant health, top plants,
  typology, size distribution, recent photo reports and activity.
- **Plant Master:** one search across every field (barcode, common/botanical name, variety, origin, source, site…),
  filters, sorting, Excel (CSV) export.
- **Plant page:** all details, size breakdown, QR code with **Download QR label** (PNG with logo), your existing
  OneDrive QR PDF link, and the photo report history.
- **Photo reports:** take or choose photos on the phone, set health and add notes. Photos are resized automatically.
- **QR Labels:** print sheets of labels for any filtered or ticked set of plants.
- **Fields & Columns (Super Admin):** add new fields (text, number, date, dropdown, long text, link). They appear
  immediately for everyone. You can show them in the QR code or the list, hide them, or delete them.
- **Edit conflicts:** if two people edit the same plant at the same time, the second person is warned before overwriting.
- **Activity log:** who added, edited (before → after) or deleted what, and when.

**Tip for phones:** open the link and choose **Add to Home screen**. It then opens like a normal app.

## Backup

Super Admin → **Settings → Backup** (or **Full backup** in the menu) downloads all data. **Export all plants**
gives an Excel-readable CSV. Save these to your company OneDrive regularly, for example once a week.

**Supabase free plan:** 500 MB database and 1 GB photo storage, which is roughly 5,000+ report photos at the app's
resized size. A free project **pauses after 7 days with no use at all**. Normal weekly use keeps it awake; if it does
pause, open the Supabase dashboard and press **Restore**.

## Troubleshooting

| Message | Fix |
|---|---|
| "The app is not configured yet" | Fill in `config.js` (step 4). |
| "Please confirm your email first" | Open the confirmation email from Supabase (check junk mail). |
| Confirmation link opens a wrong page | Set the Site URL and Redirect URL (step 3). |
| "Waiting for approval" | The Super Admin approves the person under **Users**. |
| "No user profile was found" | The account was created before running `1_setup.sql`. Delete that user in Supabase → Authentication → Users, then create it again. |
| "You don't have permission to do this" | Your role doesn't allow it (see the table above). |
| Emails don't arrive | Supabase's built-in email sends only a few emails per hour. Wait and try again, or set up your own SMTP under Authentication → Emails. |
