-- Allow an association to cancel only its own active reservation.
-- The restrictive policy also prevents any broader UPDATE policy from
-- allowing a user to change another association's reservation.

drop policy if exists "Associations can cancel their own reservations" on public.reservations;
drop policy if exists "Limit reservation updates to owner cancellation" on public.reservations;

create policy "Associations can cancel their own reservations"
on public.reservations
as permissive
for update
to authenticated
using (
  association_id = (select auth.uid())
  and status = 'reserved'
)
with check (
  association_id = (select auth.uid())
  and status = 'cancelled'
);

create policy "Limit reservation updates to owner cancellation"
on public.reservations
as restrictive
for update
to authenticated
using (
  association_id = (select auth.uid())
  and status = 'reserved'
)
with check (
  association_id = (select auth.uid())
  and status = 'cancelled'
);

-- Associations need to know which donations already have an active reservation
-- so they do not see those donations as available.
drop policy if exists "Authenticated users can view active reservation rows" on public.reservations;
create policy "Authenticated users can view active reservation rows"
on public.reservations
for select
to authenticated
using (status = 'reserved');
