import { Injectable, NotFoundException } from '@nestjs/common';
import { OrganizationsRepository } from '../repositories/organizations.repository';

@Injectable()
export class OrganizationsService {
  constructor(private readonly organizations: OrganizationsRepository) {}

  async findById(id: string) {
    const org = await this.organizations.findById(id);
    if (!org) throw new NotFoundException('organization_not_found');
    return org;
  }

  async create(input: {
    kind: 'team' | 'enterprise' | 'company';
    name: string;
    slug: string;
    createdBy: string;
  }) {
    return this.organizations.create({
      kind:      input.kind,
      name:      input.name,
      slug:      input.slug,
      createdBy: input.createdBy,
    });
  }
}