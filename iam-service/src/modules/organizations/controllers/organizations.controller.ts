import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { OrganizationsService } from '../services/organizations.service';

@Controller('v1/organizations')
export class OrganizationsController {
  constructor(private readonly organizations: OrganizationsService) {}

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.organizations.findById(id);
  }

  @Post()
  create(@Body() body: {
    kind: 'team' | 'enterprise' | 'company';
    name: string;
    slug: string;
    createdBy: string;
  }) {
    return this.organizations.create(body);
  }
}