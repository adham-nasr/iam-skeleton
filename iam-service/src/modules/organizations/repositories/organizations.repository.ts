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