# scaffold-iam.ps1
# Usage: .\scaffold-iam.ps1 [service-name]
# Default service name: iam-service

param([string]$ServiceName = "iam-service")

$ErrorActionPreference = "Stop"

# ── Sanity check ──────────────────────────────────────────────
$nodeV = (node -v).Trim()
$nodeMajor = [int](($nodeV -replace '^v','').Split('.')[0])
if ($nodeMajor -lt 20) {
    throw "Node 20+ required; found $nodeV"
}
Write-Host "Node: $nodeV  |  npm: $(npm -v)" -ForegroundColor DarkGray

# ── Helper: write a text file as UTF-8 without BOM ────────────
function Write-File {
    param([string]$Path, [string]$Content)
    $full = Join-Path (Get-Location) $Path
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($full, $Content, [System.Text.UTF8Encoding]::new($false))
}

# ── 1. Scaffold NestJS ────────────────────────────────────────
Write-Host "`n→ Scaffolding NestJS project: $ServiceName" -ForegroundColor Cyan
nest new $ServiceName --package-manager npm --skip-git --strict
Set-Location $ServiceName

# Remove the hello-world files
Remove-Item -Force -ErrorAction SilentlyContinue `
    "src/app.controller.ts",
    "src/app.controller.spec.ts",
    "src/app.service.ts",
    "test/app.e2e-spec.ts"

# ── 2. Dependencies ───────────────────────────────────────────
Write-Host "`n→ Installing dependencies (this takes a minute)" -ForegroundColor Cyan
npm install @nestjs/config dotenv drizzle-orm pg zod | Out-Host
npm install --save-dev drizzle-kit @types/pg | Out-Host

# Add db:* scripts to package.json
npm pkg set "scripts.db:generate=drizzle-kit generate" | Out-Host
npm pkg set "scripts.db:migrate=drizzle-kit migrate"   | Out-Host
npm pkg set "scripts.db:studio=drizzle-kit studio"     | Out-Host
npm pkg set "scripts.db:check=drizzle-kit check"       | Out-Host

# ── 3. Folder tree ────────────────────────────────────────────
Write-Host "`n→ Creating folder tree" -ForegroundColor Cyan
@(
    "src/config",
    "src/common/errors",
    "src/common/filters",
    "src/common/interceptors",
    "src/common/pipes",
    "src/common/decorators",
    "src/database/schema",
    "src/database/migrations",
    "src/modules/users/controllers",
    "src/modules/users/services",
    "src/modules/users/repositories",
    "src/modules/users/dtos",
    "src/modules/users/mappers",
    "src/modules/users/schema",
    "src/modules/organizations/controllers",
    "src/modules/organizations/services",
    "src/modules/organizations/repositories",
    "src/modules/organizations/dtos",
    "src/modules/organizations/mappers",
    "src/modules/organizations/schema",
    "src/health"
) | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

# Keep empty folders in git
@(
    "src/common/errors/.gitkeep",
    "src/common/decorators/.gitkeep",
    "src/modules/users/dtos/.gitkeep",
    "src/modules/users/mappers/.gitkeep",
    "src/modules/organizations/dtos/.gitkeep",
    "src/modules/organizations/mappers/.gitkeep"
) | ForEach-Object { Write-File $_ "" }

# ── 4. Root config ────────────────────────────────────────────
Write-Host "`n→ Writing project files" -ForegroundColor Cyan

$envContent = @'
NODE_ENV=development
PORT=3000
DATABASE_URL=postgres://iam:iam@localhost:5432/iam
DATABASE_POOL_MAX=10
LOG_LEVEL=info
'@
Write-File ".env.example" $envContent
Write-File ".env"         $envContent

Write-File "drizzle.config.ts" @'
import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: [
    './src/modules/users/schema/index.ts',
    './src/modules/organizations/schema/index.ts',
  ],
  out:     './src/database/migrations',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
  verbose: true,
  strict:  true,
});
'@

# Keep drizzle.config.ts out of the build so dist/main stays at dist/main
(Get-Content tsconfig.build.json -Raw) -replace '"\*\*/\*spec\.ts"', '"**/*spec.ts", "drizzle.config.ts"' |
    Set-Content tsconfig.build.json -Encoding utf8

# ── 5. Bootstrap ──────────────────────────────────────────────
Write-File "src/main.ts" @'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
'@

Write-File "src/app.module.ts" @'
import { Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module';
import { DatabaseModule } from './database/database.module';
import { UsersModule } from './modules/users/users.module';
import { OrganizationsModule } from './modules/organizations/organizations.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [ConfigModule, DatabaseModule, UsersModule, OrganizationsModule, HealthModule],
})
export class AppModule {}
'@

# ── 6. Config ─────────────────────────────────────────────────
Write-File "src/config/config.schema.ts" @'
import { z } from 'zod';

export const EnvSchema = z.object({
  NODE_ENV:          z.enum(['development', 'test', 'production']).default('development'),
  PORT:              z.coerce.number().default(3000),
  DATABASE_URL:      z.string().url(),
  DATABASE_POOL_MAX: z.coerce.number().default(10),
  LOG_LEVEL:         z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

export type Env = z.infer<typeof EnvSchema>;
'@

Write-File "src/config/config.module.ts" @'
import { Global, Module } from '@nestjs/common';
import { ConfigModule as NestConfigModule } from '@nestjs/config';
import { EnvSchema } from './config.schema';

@Global()
@Module({
  imports: [
    NestConfigModule.forRoot({
      isGlobal: true,
      validate: (raw) => EnvSchema.parse(raw),
    }),
  ],
})
export class ConfigModule {}
'@

# ── 7. Database ───────────────────────────────────────────────
Write-File "src/database/database.provider.ts" @'
import { Provider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { drizzle, NodePgDatabase } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

export const DRIZZLE = Symbol('DRIZZLE');
export type DrizzleDb = NodePgDatabase<typeof schema>;

export const drizzleProvider: Provider = {
  provide: DRIZZLE,
  inject: [ConfigService],
  useFactory: (config: ConfigService): DrizzleDb => {
    const pool = new Pool({
      connectionString: config.getOrThrow<string>('DATABASE_URL'),
      max: config.get<number>('DATABASE_POOL_MAX') ?? 10,
    });
    return drizzle(pool, { schema });
  },
};
'@

Write-File "src/database/database.module.ts" @'
import { Global, Module } from '@nestjs/common';
import { drizzleProvider } from './database.provider';

@Global()
@Module({ providers: [drizzleProvider], exports: [drizzleProvider] })
export class DatabaseModule {}
'@

Write-File "src/database/schema/index.ts" @'
export * from '../../modules/users/schema';
export * from '../../modules/organizations/schema';
'@

# ── 8. Users schema ───────────────────────────────────────────
Write-File "src/modules/users/schema/user.schema.ts" @'
import { pgSchema, uuid, text } from 'drizzle-orm/pg-core';

export const usersSchema = pgSchema('users');

export const users = usersSchema.table('users', {
  id:       uuid('id').primaryKey().defaultRandom(),
  kind:     text('kind').notNull(),
  username: text('username').notNull().unique(),
  status:   text('status').notNull().default('active'),
});

export type User    = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
'@

Write-File "src/modules/users/schema/human.schema.ts" @'
import { uuid, text, date } from 'drizzle-orm/pg-core';
import { usersSchema, users } from './user.schema';

export const humans = usersSchema.table('humans', {
  userId:    uuid('user_id').primaryKey().references(() => users.id, { onDelete: 'cascade' }),
  legalName: text('legal_name'),
  birthDate: date('birth_date'),
  ageGroup:  text('age_group').notNull(),
  locale:    text('locale').notNull(),
  region:    text('region'),
});

export type Human    = typeof humans.$inferSelect;
export type NewHuman = typeof humans.$inferInsert;
'@

Write-File "src/modules/users/schema/index.ts" @'
export * from './user.schema';
export * from './human.schema';
'@

# ── 9. Organizations schema ───────────────────────────────────
Write-File "src/modules/organizations/schema/organization.schema.ts" @'
import { pgSchema, uuid, text, boolean } from 'drizzle-orm/pg-core';
import { users } from '../../users/schema/user.schema';

export const orgsSchema = pgSchema('organizations');

export const organizations = orgsSchema.table('organizations', {
  id:              uuid('id').primaryKey().defaultRandom(),
  kind:            text('kind').notNull(),
  name:            text('name').notNull(),
  slug:            text('slug').notNull().unique(),
  createdBy:       uuid('created_by').notNull().references(() => users.id),
  requiresTwoStep: boolean('requires_two_step').notNull().default(true),
  status:          text('status').notNull().default('active'),
});

export type Organization    = typeof organizations.$inferSelect;
export type NewOrganization = typeof organizations.$inferInsert;
'@

Write-File "src/modules/organizations/schema/team.schema.ts" @'
import { uuid } from 'drizzle-orm/pg-core';
import { orgsSchema, organizations } from './organization.schema';

export const teams = orgsSchema.table('teams', {
  organizationId: uuid('organization_id')
    .primaryKey()
    .references(() => organizations.id, { onDelete: 'cascade' }),
});

export type Team    = typeof teams.$inferSelect;
export type NewTeam = typeof teams.$inferInsert;
'@

Write-File "src/modules/organizations/schema/index.ts" @'
export * from './organization.schema';
export * from './team.schema';
'@

# ── 10. Users module ──────────────────────────────────────────
Write-File "src/modules/users/users.module.ts" @'
import { Module } from '@nestjs/common';
import { UsersController } from './controllers/users.controller';
import { UsersService } from './services/users.service';
import { UsersRepository } from './repositories/users.repository';

@Module({
  controllers: [UsersController],
  providers:   [UsersService, UsersRepository],
  exports:     [UsersService],
})
export class UsersModule {}
'@

Write-File "src/modules/users/repositories/users.repository.ts" @'
import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DRIZZLE, type DrizzleDb } from '../../../database/database.provider';
import { users, type NewUser, type User } from '../schema/user.schema';

@Injectable()
export class UsersRepository {
  constructor(@Inject(DRIZZLE) private readonly db: DrizzleDb) {}

  async findById(id: string): Promise<User | undefined> {
    const [row] = await this.db.select().from(users).where(eq(users.id, id)).limit(1);
    return row;
  }

  async findByUsername(username: string): Promise<User | undefined> {
    const [row] = await this.db.select().from(users).where(eq(users.username, username)).limit(1);
    return row;
  }

  async create(data: NewUser): Promise<User> {
    const [row] = await this.db.insert(users).values(data).returning();
    return row;
  }
}
'@

Write-File "src/modules/users/services/users.service.ts" @'
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { UsersRepository } from '../repositories/users.repository';

export interface CreateUserInput {
  kind:     'human' | 'agent';
  username: string;
}

@Injectable()
export class UsersService {
  constructor(private readonly users: UsersRepository) {}

  async findById(id: string) {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundException('user_not_found');
    return user;
  }

  async create(input: CreateUserInput) {
    if (await this.users.findByUsername(input.username)) {
      throw new ConflictException('username_taken');
    }
    return this.users.create({ kind: input.kind, username: input.username });
  }
}
'@

Write-File "src/modules/users/controllers/users.controller.ts" @'
import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { UsersService } from '../services/users.service';

@Controller('v1/users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.findById(id);
  }

  @Post()
  create(@Body() body: { kind: 'human' | 'agent'; username: string }) {
    return this.users.create(body);
  }
}
'@

# ── 11. Organizations module ──────────────────────────────────
Write-File "src/modules/organizations/organizations.module.ts" @'
import { Module } from '@nestjs/common';
import { OrganizationsController } from './controllers/organizations.controller';
import { OrganizationsService } from './services/organizations.service';
import { OrganizationsRepository } from './repositories/organizations.repository';

@Module({
  controllers: [OrganizationsController],
  providers:   [OrganizationsService, OrganizationsRepository],
  exports:     [OrganizationsService],
})
export class OrganizationsModule {}
'@

Write-File "src/modules/organizations/repositories/organizations.repository.ts" @'
import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DRIZZLE, type DrizzleDb } from '../../../database/database.provider';
import { organizations, type NewOrganization, type Organization } from '../schema/organization.schema';

@Injectable()
export class OrganizationsRepository {
  constructor(@Inject(DRIZZLE) private readonly db: DrizzleDb) {}

  async findById(id: string): Promise<Organization | undefined> {
    const [row] = await this.db.select().from(organizations).where(eq(organizations.id, id)).limit(1);
    return row;
  }

  async create(data: NewOrganization): Promise<Organization> {
    const [row] = await this.db.insert(organizations).values(data).returning();
    return row;
  }
}
'@

Write-File "src/modules/organizations/services/organizations.service.ts" @'
import { Injectable, NotFoundException } from '@nestjs/common';
import { OrganizationsRepository } from '../repositories/organizations.repository';

@Injectable()
export class OrganizationsService {
  constructor(private readonly organizations: OrganizationsRepository) {}

  async findById(id: string) {
    const org = await this.organizations.findById(id);
    if (!org) throw new NotFoundException('organization_not_found');
    return org;
  }

  async create(input: {
    kind: 'team' | 'enterprise' | 'company';
    name: string;
    slug: string;
    createdBy: string;
  }) {
    return this.organizations.create({
      kind:      input.kind,
      name:      input.name,
      slug:      input.slug,
      createdBy: input.createdBy,
    });
  }
}
'@

Write-File "src/modules/organizations/controllers/organizations.controller.ts" @'
import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { OrganizationsService } from '../services/organizations.service';

@Controller('v1/organizations')
export class OrganizationsController {
  constructor(private readonly organizations: OrganizationsService) {}

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.organizations.findById(id);
  }

  @Post()
  create(@Body() body: {
    kind: 'team' | 'enterprise' | 'company';
    name: string;
    slug: string;
    createdBy: string;
  }) {
    return this.organizations.create(body);
  }
}
'@

# ── 12. Health ────────────────────────────────────────────────
Write-File "src/health/health.module.ts" @'
import { Controller, Get, Inject, Module } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DRIZZLE, type DrizzleDb } from '../database/database.provider';

@Controller('health')
class HealthController {
  constructor(@Inject(DRIZZLE) private readonly db: DrizzleDb) {}

  @Get()
  ok() { return { ok: true }; }

  @Get('ready')
  async ready() {
    await this.db.execute(sql`select 1`);
    return { ok: true };
  }
}

@Module({ controllers: [HealthController] })
export class HealthModule {}
'@

# ── Done ──────────────────────────────────────────────────────
Write-Host "`n✓ Skeleton ready in .\$ServiceName" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  cd $ServiceName"
Write-Host "  npm run db:generate    # creates the first migration"
Write-Host "  npm run db:migrate     # applies to iam-pg"
Write-Host "  npm run start:dev      # boots on http://localhost:3000"