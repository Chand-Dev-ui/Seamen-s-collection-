-- SEAMEN'S COLLECTION - Supabase setup
create table if not exists public.products (id uuid primary key default gen_random_uuid(),name text not null,category text not null check(category in ('Beads','Resin','Crochet')),price numeric(12,2) not null default 0,stock integer not null default 0,description text default '',image_url text default '',active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.orders (id uuid primary key default gen_random_uuid(),order_number text unique not null,customer_name text not null,phone text not null,city text not null,address text not null,payment_method text not null default 'Bank Transfer' check(payment_method='Bank Transfer'),total numeric(12,2) not null default 0,status text not null default 'New' check(status in ('New','Confirmed','Packed','Shipped','Delivered','Cancelled')),created_at timestamptz not null default now());
create table if not exists public.order_items (id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,product_id uuid references public.products(id) on delete set null,product_name text not null,quantity integer not null check(quantity>0),unit_price numeric(12,2) not null);
alter table public.products enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security;
drop policy if exists "Public can view active products" on public.products; create policy "Public can view active products" on public.products for select using(active=true);
drop policy if exists "Admins manage products" on public.products; create policy "Admins manage products" on public.products for all to authenticated using(true) with check(true);
drop policy if exists "Anyone can create orders" on public.orders; create policy "Anyone can create orders" on public.orders for insert to anon,authenticated with check(payment_method='Bank Transfer');
drop policy if exists "Admins view orders" on public.orders; create policy "Admins view orders" on public.orders for select to authenticated using(true);
drop policy if exists "Admins update orders" on public.orders; create policy "Admins update orders" on public.orders for update to authenticated using(true) with check(true);
drop policy if exists "Admins delete orders" on public.orders; create policy "Admins delete orders" on public.orders for delete to authenticated using(true);
drop policy if exists "Anyone can create order items" on public.order_items; create policy "Anyone can create order items" on public.order_items for insert to anon,authenticated with check(true);
drop policy if exists "Admins view order items" on public.order_items; create policy "Admins view order items" on public.order_items for select to authenticated using(true);
insert into storage.buckets(id,name,public) values('product-images','product-images',true) on conflict(id) do nothing;
drop policy if exists "Public can view product images" on storage.objects; create policy "Public can view product images" on storage.objects for select using(bucket_id='product-images');
drop policy if exists "Admins upload product images" on storage.objects; create policy "Admins upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images');
drop policy if exists "Admins update product images" on storage.objects; create policy "Admins update product images" on storage.objects for update to authenticated using(bucket_id='product-images');
drop policy if exists "Admins delete product images" on storage.objects; create policy "Admins delete product images" on storage.objects for delete to authenticated using(bucket_id='product-images');
drop function if exists public.place_order(text,text,text,text,text,jsonb);
create or replace function public.place_order(p_customer_name text,p_phone text,p_city text,p_address text,p_payment_method text,p_items jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_order_id uuid; v_num text; v_total numeric(12,2):=0; v jsonb; v_product public.products%rowtype; v_qty integer;
begin
 if p_payment_method <> 'Bank Transfer' then raise exception 'Only Bank Transfer is available'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
 v_num:='SC-'||lpad(floor(random()*100000000)::bigint::text,8,'0');
 while exists(select 1 from public.orders where order_number=v_num) loop v_num:='SC-'||lpad(floor(random()*100000000)::bigint::text,8,'0'); end loop;
 for v in select * from jsonb_array_elements(p_items) loop
   v_qty=greatest(1,coalesce((v->>'q')::integer,0));
   select * into v_product from public.products where id=(v->>'id')::uuid and active=true for update;
   if not found then raise exception 'Product is unavailable'; end if;
   if v_product.stock < v_qty then raise exception 'Not enough stock for %',v_product.name; end if;
   v_total:=v_total+(v_product.price*v_qty);
 end loop;
 insert into public.orders(order_number,customer_name,phone,city,address,payment_method,total) values(v_num,p_customer_name,p_phone,p_city,p_address,'Bank Transfer',v_total) returning id into v_order_id;
 for v in select * from jsonb_array_elements(p_items) loop
   v_qty=greatest(1,coalesce((v->>'q')::integer,0)); select * into v_product from public.products where id=(v->>'id')::uuid for update;
   update public.products set stock=stock-v_qty where id=v_product.id;
   insert into public.order_items(order_id,product_id,product_name,quantity,unit_price) values(v_order_id,v_product.id,v_product.name,v_qty,v_product.price);
 end loop;
 return jsonb_build_object('id',v_order_id,'order_number',v_num,'total',v_total);
end; $$;
drop function if exists public.track_order(text,text);
create or replace function public.track_order(p_order_number text,p_phone text) returns table(id uuid,order_number text,total numeric,status text,created_at timestamptz) language sql security definer set search_path=public as $$ select o.id,o.order_number,o.total,o.status,o.created_at from public.orders o where lower(o.order_number)=lower(p_order_number) and o.phone=p_phone limit 1; $$;
drop function if exists public.cancel_order(uuid);
create or replace function public.cancel_order(p_order_id uuid) returns boolean language plpgsql security definer set search_path=public as $$ declare o public.orders%rowtype; i record; begin select * into o from public.orders where id=p_order_id for update; if not found then raise exception 'Order not found'; end if; if o.status not in ('New','Confirmed') then raise exception 'This order can no longer be cancelled'; end if; for i in select product_id,quantity from public.order_items where order_id=p_order_id loop update public.products set stock=stock+i.quantity where id=i.product_id; end loop; update public.orders set status='Cancelled' where id=p_order_id; return true; end; $$;
drop function if exists public.admin_update_order_status(uuid,text);
create or replace function public.admin_update_order_status(p_order_id uuid,p_status text) returns boolean language plpgsql security definer set search_path=public as $$ declare o public.orders%rowtype; i record; begin if p_status not in ('New','Confirmed','Packed','Shipped','Delivered','Cancelled') then raise exception 'Invalid status'; end if; select * into o from public.orders where id=p_order_id for update; if not found then raise exception 'Order not found'; end if; if o.status='Cancelled' and p_status<>'Cancelled' then raise exception 'Cancelled orders cannot be reopened'; end if; if p_status='Cancelled' and o.status<>'Cancelled' then for i in select product_id,quantity from public.order_items where order_id=p_order_id loop update public.products set stock=stock+i.quantity where id=i.product_id; end loop; end if; update public.orders set status=p_status where id=p_order_id; return true; end; $$;
grant execute on function public.place_order(text,text,text,text,text,jsonb) to anon,authenticated; grant execute on function public.track_order(text,text) to anon,authenticated; grant execute on function public.cancel_order(uuid) to anon,authenticated; grant execute on function public.admin_update_order_status(uuid,text) to authenticated;

-- FINAL AUTH/ADMIN SECURITY MIGRATION
create table if not exists public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admin_users enable row level security;
create or replace function public.is_admin() returns boolean language sql security definer set search_path=public as $$ select exists(select 1 from public.admin_users where user_id=auth.uid()); $$;
grant execute on function public.is_admin() to anon,authenticated;
drop policy if exists "Admins manage products" on public.products; create policy "Admins manage products" on public.products for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "Admins view orders" on public.orders; create policy "Admins view orders" on public.orders for select to authenticated using(public.is_admin());
drop policy if exists "Admins update orders" on public.orders; create policy "Admins update orders" on public.orders for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "Admins delete orders" on public.orders; create policy "Admins delete orders" on public.orders for delete to authenticated using(public.is_admin());
drop policy if exists "Anyone can create order items" on public.order_items; create policy "Anyone can create order items" on public.order_items for insert to anon,authenticated with check(false);
drop policy if exists "Admins view order items" on public.order_items; create policy "Admins view order items" on public.order_items for select to authenticated using(public.is_admin());
drop policy if exists "Admins upload product images" on storage.objects; create policy "Admins upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.is_admin());
drop policy if exists "Admins update product images" on storage.objects; create policy "Admins update product images" on storage.objects for update to authenticated using(bucket_id='product-images' and public.is_admin()) with check(bucket_id='product-images' and public.is_admin());
drop policy if exists "Admins delete product images" on storage.objects; create policy "Admins delete product images" on storage.objects for delete to authenticated using(bucket_id='product-images' and public.is_admin());
drop function if exists public.cancel_order(uuid,text);
create or replace function public.cancel_order(p_order_id uuid,p_phone text) returns boolean language plpgsql security definer set search_path=public as $$ declare o public.orders%rowtype; i record; begin select * into o from public.orders where id=p_order_id and phone=p_phone for update; if not found then raise exception 'Order not found'; end if; if o.status not in ('New','Confirmed') then raise exception 'This order can no longer be cancelled'; end if; for i in select product_id,quantity from public.order_items where order_id=p_order_id loop update public.products set stock=stock+i.quantity where id=i.product_id; end loop; update public.orders set status='Cancelled' where id=p_order_id; return true; end; $$;
grant execute on function public.cancel_order(uuid,text) to anon,authenticated;


-- AUTO-CONNECT ADMIN ACCOUNT
-- This automatically makes the existing Supabase account with this exact email an admin.
insert into public.admin_users(user_id)
select id from auth.users
where lower(email)=lower('chandrohaan797@gmail.com')
on conflict (user_id) do nothing;
