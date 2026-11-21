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