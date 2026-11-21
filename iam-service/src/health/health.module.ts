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