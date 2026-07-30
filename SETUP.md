# Soham PG Management App — Setup & Run Guide

## 1. Environment Configuration (`.env`)
The `.env` file is already created in the root directory with your credentials:
```env
SUPABASE_URL=https://zbubmbabexopfxbrlxyf.supabase.co
SUPABASE_ANON_KEY=sb_publishable_2uQlTeGiKvtnf6CPaDkunA_PcaScDDt
RESEND_API_KEY=your_resend_api_key_here
OWNER_EMAIL=owner@soham.com
UPI_ID=chetnabharvada1234@okhdfcbank
PG_NAME=Soham
```

---

## 2. Supabase Backend Setup

### Step A: Run SQL Migration
1. Go to your [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **SQL Editor** -> **New Query**.
3. Paste and run the content of `supabase/migrations/001_initial_schema.sql`.

### Step B: Seed Owner Account
1. In Supabase Dashboard, go to **Authentication** -> **Users** -> **Add User**.
2. **Email**: `owner@soham.com`
3. **Password**: `Soham@2025`
4. Set User Metadata:
   ```json
   {
     "name": "Soham Owner",
     "role": "owner"
   }
   ```
5. In SQL Editor, run:
   ```sql
   UPDATE public.profiles 
   SET role = 'owner', name = 'Soham Owner' 
   WHERE email = 'owner@soham.com';
   ```

---

## 3. Run the Flutter App
To launch on your connected mobile device or emulator:
```bash
flutter run
```

### Credentials & Roles:
- **Owner Account**: Log in with `owner@soham.com` / `Soham@2025` to access the Owner Dashboard.
- **Tenant Account**: Click "Create an account" on the login screen to register as a Tenant.
