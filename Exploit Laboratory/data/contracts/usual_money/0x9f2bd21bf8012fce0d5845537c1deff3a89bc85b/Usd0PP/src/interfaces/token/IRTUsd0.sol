// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRTUsd0 is IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by an account with the PAUSING_CONTRACTS_ROLE
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by an account with the UNPAUSING_CONTRACTS_ROLE
    function unpause() external;

    /// @notice mint rt-USD0 token
    /// @dev Can only be called by RTUSD0_MINT_ROLE
    /// @param to address of the account who want to mint their token
    /// @param amount the amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice burnFrom rt-USD0 token
    /// @dev Can only be called by RTUSD0_BURN_ROLE
    /// @param account address of the account who want to burn
    /// @param amount the amount of tokens to burn
    function burnFrom(address account, uint256 amount) external;
}

