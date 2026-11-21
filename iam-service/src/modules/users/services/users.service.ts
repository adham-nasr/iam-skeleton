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