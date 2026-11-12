-- Expose only the plan assigned to the authenticated customer's own subscription.
alter table public.subscription_plans enable row level security;

drop policy if exists "owners can read their assigned subscription plan" on public.subscription_plans;
create policy "owners can read their assigned subscription plan"
on public.subscription_plans
for select
to authenticated
using (
  exists (
    select 1
    from public.user_subscriptions s
    where s.user_id = (select auth.uid())
      and s.plan_id = subscription_plans.id
  )
);
