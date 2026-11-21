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