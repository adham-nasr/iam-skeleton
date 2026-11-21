import { uuid } from 'drizzle-orm/pg-core';
import { orgsSchema, organizations } from './organization.schema';

export const teams = orgsSchema.table('teams', {
  organizationId: uuid('organization_id')
    .primaryKey()
    .references(() => organizations.id, { onDelete: 'cascade' }),
});

export type Team    = typeof teams.$inferSelect;
export type NewTeam = typeof teams.$inferInsert;