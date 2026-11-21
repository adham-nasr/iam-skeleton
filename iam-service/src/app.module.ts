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