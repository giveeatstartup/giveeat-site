-- Allow a food business to see reservation records for its own donations.
create policy "Businesses can view reservations for their donations"
on public.reservations
for select
to authenticated
using (
  exists (
    select 1
    from public.donations
    where donations.id = reservations.donation_id
      and donations.business_id = (select auth.uid())
  )
);
