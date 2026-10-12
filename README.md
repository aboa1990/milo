# Milo Academy Tournament Room Allocation – Vercel version

A static web app (no build step) that uses **Supabase** (free tier) for the database and sign-in,
and **Vercel** for hosting. Guests are signed in anonymously, so they do not need an account.
Admins sign in with an email link.

## 1. Create the database (Supabase)
1. Go to https://supabase.com, create a project (choose a region close to the Maldives, for example Singapore).
2. **Authentication → Sign In / Providers**: turn on **Allow anonymous sign-ins**. Leave **Email** on.
3. **SQL Editor → New query**: paste all of `supabase.sql` and run it.
4. New query again, run this with your own email (this makes you the admin):
   `insert into public.admins (email) values ('you@example.com');`
5. New query again: paste `seed.sql` and run it (adds your properties, the 36 teams and the focal point).
6. **Project Settings → API**: copy the **Project URL** and the **anon public** key.
7. Open `config.js` and paste both values.
   Never put the `service_role` key anywhere in this project.

## 2. Deploy to Vercel
Option A, GitHub: put this folder in a GitHub repository, then in Vercel choose
**Add New → Project**, import the repository, set **Framework Preset = Other**, leave the build
command empty and the output directory as `.`, then **Deploy**.

Option B, command line: install Node.js, open a terminal in this folder and run
`npx vercel --prod`. Answer the questions (no build command, output directory `.`).

## 3. Tell Supabase your website address
After deploying, copy your address (for example `https://milo-rooms.vercel.app`) into
**Authentication → URL Configuration**: set **Site URL** to it and add it under **Redirect URLs**.
Do the same again if you add a custom domain (Vercel → Settings → Domains).

## 4. Check it works
1. Open the site on a phone. You should see the rooms and the Teams tab.
2. Scroll to the bottom, tap **Admin login**, enter your admin email, open the link from the email.
   The **Manage** tab should now appear. Guests never see it.
3. Make a test booking, confirm it in Manage, then cancel it.

## What the database rules do
- Everyone signed in can read the data (the page itself hides other people's bookings from guests).
- Only admins can change properties, rooms, rates, teams, payments, the directory and settings.
- Guests can add bookings and edit or cancel only their own, but cannot confirm a booking or assign rooms.
- To add another admin, run the `insert into public.admins ...` line with their email.

## Notes
- Back up with **Manage → Export to Excel**, and Supabase also keeps backups on paid plans.
- A guest's bookings are tied to their browser. If they clear their browser data they can still find a
  booking with the reference code and phone number (My stay → Find a booking).
- Free tiers: Supabase pauses projects after a week without any activity, so open the site once a week
  before the event or upgrade.
- Texts and emails are not sent automatically. Use the WhatsApp, SMS and Copy message buttons.
