-- Save the name and organization entered during GiveEat registration.
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

  insert into public.profiles (id, full_name, organization_name, role)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'organization_name', ''),
    requested_role
  );

  return new;
end;
$$;