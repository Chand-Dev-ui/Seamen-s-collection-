# SEAWAIS LIVE STORE

This version is a real-backend-ready static e-commerce site using Supabase.

## Setup (required once)
1. Create a free Supabase project.
2. Open SQL Editor and run `supabase.sql`.
3. In Supabase Authentication > Users, create the admin email/password you will use for `/admin/`.
4. Open Project Settings > API and copy:
   - Project URL
   - anon/public key
5. Paste them into `assets/config.js`.
6. Upload the whole folder to GitHub.
7. Enable GitHub Pages.

## After setup
Customer store: your GitHub Pages URL
Admin: your GitHub Pages URL + `/admin/`

The admin panel lets you:
- add/edit/delete (deactivate) products
- change price, stock, category and image URL
- view real customer orders
- view customer address/phone/payment
- change order status

## Product photos
For the simplest setup, upload images somewhere public and paste the image URL in the product editor. A Supabase Storage bucket and policies are also created by the SQL for `product-images`; you can later connect the admin image field to uploads.

## Security
Never put a Supabase `service_role` key in this website. Only the public/anon key belongs in `assets/config.js`.
