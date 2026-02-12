// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {
    IAccessControlDefaultAdminRules
} from "openzeppelin-contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

interface IRegistryAccess is IAccessControlDefaultAdminRules {
    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the admin role for a specific role
    /// @param role The role to set the admin for
    /// @param adminRole The admin role to set
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;
}
