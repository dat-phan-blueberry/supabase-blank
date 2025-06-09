## Local development

### Requirements

- Docker
- Deno
- Supabase CLI (optional, can be used locally via node_modules)
- Yarn

### Scripts

- Start supabase stack

```bash
yarn start
```

- Stop supabase stack

```bash
yarn stop
```

- start functions watcher (this command has hot-reloading capabilities)

```bash
yarn serve
```

### Edge Function

- Deploy edge function

```bash
supabase functions deploy function-name
```

### Migration

- Generate migration script base on diff

```bash
supabase db diff --local -f script-name
```

For more information, refer to the [Diff local database](https://supabase.com/docs/reference/cli/supabase-db-diff).

- Testing migration script

```bash
supabase db reset
```

- Apply pending migrations to local database

```bash
supabase migration up --local
```

For more information, refer to the [Manage database migration scripts](https://supabase.com/docs/reference/cli/supabase-migration).

- Push migration to a project

```bash
supabase db push
```

### Util scripts

- Link local project

```bash
supabase link --project-ref your-project-id
```

- Generate DB Schema type

```bash
supabase  gen types typescript -s auth,public,extensions --local  > schema.generated.ts
```

### Working with Deno

- Cache the dependencies

```bash
deno cache --import-map=./supabase/functions/import_map.json  supabase/functions/**/*.ts
```

### Install package

- Go to this file, define the package

```bash
/supabase/functions/import_map.json
```
