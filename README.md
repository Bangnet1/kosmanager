# Kos Manager

Glassmorphism V2 property management dashboard for multiple boarding-house locations.

## Local development
1. Create a dedicated Supabase project.
2. Apply `supabase/migrations/202611050001_initial_schema.sql` in that project's SQL Editor.
3. Create the owner account through Supabase Auth (public sign-up is intentionally disabled).
4. Copy `.env.example` to `.env` and fill `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Run `npm install && npm run dev`.

## GitHub Pages deployment
A GitHub Actions workflow builds Vite and publishes the `dist/` directory. Configure repository Actions secrets `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Never add a Supabase service-role or secret key to frontend code.

For GitHub Pages project-site hosting, Vite base path is `/kosmanager/`. A custom domain deployed at the domain root requires changing this to `/`.

## Security
All application tables use owner-scoped RLS. Identity files and uploads use private Supabase Storage buckets. Apply the migration only to the dedicated Kos Manager project. No existing Supabase projects are changed by this repository setup.
