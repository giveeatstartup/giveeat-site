-- Allow a business to read the public name of an association
-- only when that association has reserved one of the business's donations.
create policy "Businesses can view profiles of associations reserving their donations"
on public.profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.reservations
    join public.donations
      on donations.id = reservations.donation_id
    where reservations.association_id = profiles.id
      and donations.business_id = (select auth.uid())
  )
);
