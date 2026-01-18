-- Enable RLS on the shopping_cart table
alter table shopping_cart enable row level security;

-- Policy for SELECT
create policy "Users can view their own shopping cart items"
on shopping_cart for select
using (auth.uid() = user_id);

-- Policy for INSERT
create policy "Users can insert their own shopping cart items"
on shopping_cart for insert
with check (auth.uid() = user_id);

-- Policy for UPDATE
create policy "Users can update their own shopping cart items"
on shopping_cart for update
using (auth.uid() = user_id);

-- Policy for DELETE
create policy "Users can delete their own shopping cart items"
on shopping_cart for delete
using (auth.uid() = user_id);
