-- Delete a property and all records that are structurally tied to its rooms.
-- Tenant profiles and tenant-level payments are retained for audit/reuse.
create or replace function public.delete_property_with_rooms(p_property_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.properties
    where id = p_property_id and owner_id = auth.uid()
  ) then
    raise exception 'Properti tidak ditemukan atau bukan milik akun ini.';
  end if;

  -- Maintenance records and their updates.
  delete from public.maintenance_updates
  where request_id in (
    select id from public.maintenance_requests
    where property_id = p_property_id and owner_id = auth.uid()
  );
  delete from public.maintenance_requests
  where property_id = p_property_id and owner_id = auth.uid();

  -- Invoices and their dependent records.
  delete from public.reminder_logs
  where invoice_id in (
    select id from public.invoices
    where room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      and owner_id = auth.uid()
  );
  delete from public.payment_allocations
  where invoice_id in (
    select id from public.invoices
    where room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      and owner_id = auth.uid()
  );
  delete from public.invoice_items
  where invoice_id in (
    select id from public.invoices
    where room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      and owner_id = auth.uid()
  );
  update public.transactions set reversal_of = null
  where reversal_of in (
    select id from public.transactions
    where (property_id = p_property_id
      or room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid()))
      and owner_id = auth.uid()
  );
  delete from public.transactions
  where owner_id = auth.uid()
    and (property_id = p_property_id
      or room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      or invoice_id in (
        select id from public.invoices
        where room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      ));

  delete from public.invoices
  where owner_id = auth.uid()
    and room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid());

  -- Charges, occupancy history, agreements, and room metadata.
  delete from public.additional_charges
  where owner_id = auth.uid()
    and (property_id = p_property_id
      or room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      or agreement_id in (
        select id from public.rental_agreements
        where room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid())
      ));
  delete from public.occupancies
  where owner_id = auth.uid()
    and room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid());
  delete from public.rental_agreements
  where owner_id = auth.uid()
    and room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid());
  delete from public.room_photos
  where owner_id = auth.uid()
    and room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid());
  delete from public.room_amenities
  where owner_id = auth.uid()
    and room_id in (select id from public.rooms where property_id = p_property_id and owner_id = auth.uid());

  delete from public.rooms
  where owner_id = auth.uid() and property_id = p_property_id;
  delete from public.properties
  where owner_id = auth.uid() and id = p_property_id;
end;
$$;

revoke all on function public.delete_property_with_rooms(uuid) from public;
grant execute on function public.delete_property_with_rooms(uuid) to authenticated;
