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