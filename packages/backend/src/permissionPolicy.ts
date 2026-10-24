// Ownership-based permission policy.
// - platform-team members: everything
// - everyone else: Components/APIs/Resources owned by one of their groups,
//   plus shared kinds (Groups, Users, Systems, Domains, Templates, Locations)
import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  AuthorizeResult,
  PolicyDecision,
  isPermission,
} from '@backstage/plugin-permission-common';
import {
  PermissionPolicy,
  PolicyQuery,
  PolicyQueryUser,
} from '@backstage/plugin-permission-node';
import { policyExtensionPoint } from '@backstage/plugin-permission-node/alpha';
import {
  catalogConditions,
  createCatalogConditionalDecision,
} from '@backstage/plugin-catalog-backend/alpha';
import { catalogEntityReadPermission } from '@backstage/plugin-catalog-common/alpha';

const ADMIN_GROUP = 'group:default/platform-team';
const SHARED_KINDS = [
  'Group',
  'User',
  'System',
  'Domain',
  'Template',
  'Location',
];

class OwnershipPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser,
  ): Promise<PolicyDecision> {
    const ownership = user?.info.ownershipEntityRefs ?? [];

    if (ownership.includes(ADMIN_GROUP)) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (isPermission(request.permission, catalogEntityReadPermission)) {
      return createCatalogConditionalDecision(request.permission, {
        anyOf: [
          catalogConditions.isEntityOwner({ claims: ownership }),
          catalogConditions.isEntityKind({ kinds: SHARED_KINDS }),
        ],
      });
    }

    return { result: AuthorizeResult.ALLOW };
  }
}

export default createBackendModule({
  pluginId: 'permission',
  moduleId: 'ownership-policy',
  register(reg) {
    reg.registerInit({
      deps: { policy: policyExtensionPoint },
      async init({ policy }) {
        policy.setPolicy(new OwnershipPolicy());
      },
    });
  },
});
