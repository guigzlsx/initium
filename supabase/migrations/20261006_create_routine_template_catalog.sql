create extension if not exists pgcrypto;

create table if not exists public.routine_template_categories (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    name_fr text not null,
    name_en text not null,
    icon text not null,
    sort_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.routine_templates (
    id uuid primary key default gen_random_uuid(),
    category_id uuid not null references public.routine_template_categories(id) on delete cascade,
    slug text not null unique,
    name_fr text not null,
    name_en text not null,
    description_fr text,
    description_en text,
    icon text,
    default_margin_seconds integer not null default 300 check (default_margin_seconds >= 0),
    sort_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.routine_template_steps (
    id uuid primary key default gen_random_uuid(),
    template_id uuid not null references public.routine_templates(id) on delete cascade,
    step_key text not null,
    title_fr text not null,
    title_en text not null,
    estimated_duration_seconds integer not null check (estimated_duration_seconds > 0),
    sort_order integer not null default 0,
    is_optional boolean not null default false,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (template_id, step_key)
);

create table if not exists public.routine_template_keywords (
    id uuid primary key default gen_random_uuid(),
    template_id uuid not null references public.routine_templates(id) on delete cascade,
    locale text not null check (locale in ('fr', 'en', 'all')),
    keyword text not null,
    weight integer not null default 1 check (weight > 0),
    created_at timestamptz not null default now(),
    unique (template_id, locale, keyword)
);

create index if not exists routine_templates_category_sort_idx
    on public.routine_templates (category_id, sort_order);
create index if not exists routine_template_steps_template_sort_idx
    on public.routine_template_steps (template_id, sort_order);
create index if not exists routine_template_keywords_template_locale_idx
    on public.routine_template_keywords (template_id, locale);

alter table public.routine_template_categories enable row level security;
alter table public.routine_templates enable row level security;
alter table public.routine_template_steps enable row level security;
alter table public.routine_template_keywords enable row level security;

drop policy if exists routine_template_categories_public_select on public.routine_template_categories;
create policy routine_template_categories_public_select
    on public.routine_template_categories
    for select to anon, authenticated
    using (is_active = true);

drop policy if exists routine_templates_public_select on public.routine_templates;
create policy routine_templates_public_select
    on public.routine_templates
    for select to anon, authenticated
    using (
        is_active = true
        and exists (
            select 1
            from public.routine_template_categories category
            where category.id = category_id and category.is_active = true
        )
    );

drop policy if exists routine_template_steps_public_select on public.routine_template_steps;
create policy routine_template_steps_public_select
    on public.routine_template_steps
    for select to anon, authenticated
    using (
        is_active = true
        and exists (
            select 1
            from public.routine_templates template
            where template.id = template_id and template.is_active = true
        )
    );

drop policy if exists routine_template_keywords_public_select on public.routine_template_keywords;
create policy routine_template_keywords_public_select
    on public.routine_template_keywords
    for select to anon, authenticated
    using (
        exists (
            select 1
            from public.routine_templates template
            where template.id = template_id and template.is_active = true
        )
    );

revoke insert, update, delete on public.routine_template_categories from anon, authenticated;
revoke insert, update, delete on public.routine_templates from anon, authenticated;
revoke insert, update, delete on public.routine_template_steps from anon, authenticated;
revoke insert, update, delete on public.routine_template_keywords from anon, authenticated;

grant select on public.routine_template_categories to anon, authenticated;
grant select on public.routine_templates to anon, authenticated;
grant select on public.routine_template_steps to anon, authenticated;
grant select on public.routine_template_keywords to anon, authenticated;
