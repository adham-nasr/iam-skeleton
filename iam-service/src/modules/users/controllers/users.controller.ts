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