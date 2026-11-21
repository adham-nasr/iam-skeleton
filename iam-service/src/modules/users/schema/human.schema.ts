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