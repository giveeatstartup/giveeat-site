-- Allow new users to choose a business or association account.
-- Admin accounts must be assigned manually by a trusted administrator.

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'business');

  if requested_role not in ('business', 'association') then
    requested_role := 'business';
  end if;

  insert into public.profiles (id, role)
  values (new.id, requested_role);

  return new;
end;
$$;
