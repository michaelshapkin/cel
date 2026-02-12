// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Approval as PermitApproval} from "src/interfaces/IDaoCollateral.sol";

interface IUsd0PP is IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a bond is unwrapped.
    /// @param user The address of the user unwrapping the bond.
    /// @param amount The amount of the bond unwrapped.
    /// @param assetRecipient The address that received the returned USD0 tokens
    event BondUnwrapped(address indexed user, uint256 amount, address assetRecipient);

    /// @notice Emitted when a bond is unwrapped.
    /// @param user The address of the user unwrapping the bond.
    /// @param amount The amount of the bond unwrapped.
    event BondUnwrapped(address indexed user, uint256 amount);

    /// @notice Emitted when a bond is deconstructed (minted)
    /// @param user The address of the user who deconstructed the bond
    /// @param amount The amount of USD0 used to create the bond
    /// @param bAssetRecipient The address that received the minted bUSD0 (bond asset) tokens
    /// @param rAssetRecipient The address that received the minted rt-USD0 (redemption token asset) tokens
    event Deconstructed(
        address indexed user, uint256 amount, address bAssetRecipient, address rAssetRecipient
    );

    /// @notice Emitted when a bond is reconstructed (burned)
    /// @param user The address of the user who reconstructed the bond
    /// @param amount The amount of bUSD0 that was burned
    /// @param assetRecipient The address that received the returned USD0 tokens
    event Reconstructed(address indexed user, uint256 amount, address assetRecipient);

    /// @notice Event emitted when a bond is early redeemed
    /// @param user The address of the user early redeeming the bond
    /// @param usd0ppAmount The amount of bUSD0 early redeemed
    event BondUnwrappedEarlyWithUsualBurn(address indexed user, uint256 usd0ppAmount);

    /// @notice Emitted when an emergency withdrawal occurs.
    /// @param account The address of the account initiating the emergency withdrawal.
    /// @param balance The balance withdrawn.
    event EmergencyWithdraw(address indexed account, uint256 balance);

    /// @notice Event emitted when the floor price is updated
    /// @param newFloorPrice The new floor price value
    event FloorPriceUpdated(uint256 newFloorPrice);

    /// @notice Event emitted when bUSD0 is unlocked to USD0
    /// @param user The address of the user unlocking bUSD0
    /// @param usd0ppAmount The amount of bUSD0 unlocked
    /// @param usd0Amount The amount of USD0 received
    event Usd0ppUnlockedFloorPrice(address indexed user, uint256 usd0ppAmount, uint256 usd0Amount);

    /// @notice Emitted when an unwrap cap is set for an address
    /// @param user The address of the user setting the unwrap cap
    /// @param cap The unwrap cap
    event UnwrapCapSet(address indexed user, uint256 cap);

    /// @notice Emitted when bUSD0 is unwrapped by a USD0PP_CAPPED_UNWRAP_ROLE address
    /// @param user The address of the user unwrapping the bond
    /// @param amount The amount of bUSD0 unwrapped
    /// @param remainingAllowance The remaining allowance of the user
    event CappedUnwrap(address indexed user, uint256 amount, uint256 remainingAllowance);

    /// @notice Event emitted when the USUAL distribution rate is set
    /// @param newRate The new USUAL distribution rate
    event UsualDistributionPerUsd0ppSet(uint256 newRate);

    /// @notice Event emitted when the duration cost factor is set
    /// @param newFactor The new duration cost factor
    event DurationCostFactorSet(uint256 newFactor);

    // @notice Event emitted when fees are swept
    // @param caller The address calling the sweep
    // @param collector The address receiving the fees
    // @param amount The amount of fees swept
    event FeeSwept(address indexed caller, address indexed collector, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by an account with the PAUSING_CONTRACTS_ROLE
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE
    function unpause() external;

    /// @notice Calculates the number of seconds from beginning to end of the bond period.
    /// @return The number of seconds.
    function totalBondTimes() external view returns (uint256);

    /// @notice get the start time
    /// @dev Used to determine if the bond can be minted.
    /// @return The block timestamp marking when the bond starts.
    function getStartTime() external view returns (uint256);

    /// @notice get the end time
    /// @dev Used to determine if the bond can be unwrapped.
    /// @return The block timestamp marking when the bond ends.
    function getEndTime() external view returns (uint256);

    /// @notice Mints Usd0PP tokens representing bonds.
    /// @dev Transfers collateral USD0 tokens and mints Usd0PP bonds.
    /// @param amountUsd0 The amount of USD0 to mint bonds for.
    function mint(uint256 amountUsd0) external;

    /// @notice Mints bUSD0 tokens representing bonds.
    /// @dev Transfers collateral USD0 tokens and mints bUSD0 bonds.
    /// @param amountUsd0 The amount of USD0 to mint bonds for.
    /// @param bAssetRecipient The address to receive the bUSD0 tokens
    /// @param rAssetRecipient The address to receive the rt-USD0 tokens
    function mint(uint256 amountUsd0, address bAssetRecipient, address rAssetRecipient) external;

    /// @notice Mints Usd0PP tokens representing bonds with permit.
    /// @dev    Transfers collateral Usd0 tokens and mints Usd0PP bonds.
    /// @param  amountUsd0 The amount of Usd0 to mint bonds for.
    /// @param  deadline The deadline for the permit.
    /// @param  v The v value for the permit.
    /// @param  r The r value for the permit.
    /// @param  s The s value for the permit.
    function mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /// @notice Unwraps the bond after maturity, returning the collateral token.
    /// @dev Only the balance of the caller is unwrapped.
    /// @dev Burns bond tokens and transfers collateral back to the user.
    function unwrap() external;

    /// @notice Unwraps all bUSD0 tokens to USD0 after the bond period ends
    /// @param assetRecipient The address to receive the returned USD0 tokens
    /// @dev This function burns all bUSD0 tokens from the caller and returns equivalent USD0
    /// @dev Can only be called after the bond period has ended and contract is not paused
    function unwrap(address assetRecipient) external;

    /// @notice function for executing the emergency withdrawal of Usd0.
    /// @param  safeAccount The address of the account to withdraw the Usd0 to.
    /// @dev    Reverts if the caller does not have the DEFAULT_ADMIN_ROLE role.
    function emergencyWithdraw(address safeAccount) external;

    /// @notice Updates the floor price
    /// @param newFloorPrice The new floor price value (18 decimal places)
    function updateFloorPrice(uint256 newFloorPrice) external;

    /// @notice Unlocks bUSD0 to USD0 at the current floor price
    /// @param usd0ppAmount The amount of bUSD0 to unlock
    function unlockUsd0ppFloorPrice(uint256 usd0ppAmount) external;

    /// @notice Allows early redemption of bUSD0 by burning USUAL
    /// @param usd0ppAmount The amount of bUSD0 to redeem
    /// @param maxUsualAmount The maximum amount of USUAL to burn
    function unlockUSD0ppWithUsual(uint256 usd0ppAmount, uint256 maxUsualAmount) external;

    /// @notice Allows early redemption of bUSD0 by burning USUAL using permit
    /// @param usd0ppAmount The amount of bUSD0 to redeem
    /// @param maxUsualAmount The maximum amount of USUAL to burn
    /// @param usualApproval The approval for the USUAL permit
    /// @param usd0ppApproval The approval for the bUSD0 permit
    function unlockUSD0ppWithUsualWithPermit(
        uint256 usd0ppAmount,
        uint256 maxUsualAmount,
        PermitApproval calldata usualApproval,
        PermitApproval calldata usd0ppApproval
    ) external;

    /// @notice Sweeps accumulated fees to the distribution module contract
    /// @return The amount of fees swept
    function sweepFees() external returns (uint256);

    /// @notice Sets the USUAL distribution per bUSD0
    /// @param newRate New daily USUAL distribution per bUSD0
    function setUsualDistributionPerUsd0pp(uint256 newRate) external;

    /// @notice Sets the duration cost factor
    /// @param newFactor New duration cost factor
    function setDurationCostFactor(uint256 newFactor) external;

    /// @notice Gets the current floor price
    /// @return The current floor price
    function getFloorPrice() external view returns (uint256);

    /// @notice Sets the unwrap capability for an address
    /// @param user The address to set the capability for
    /// @param cap The total capability amount (in bUSD0 tokens)
    function setUnwrapCap(address user, uint256 cap) external;

    /// @notice Gets the unwrap amount capability for an address
    /// @param user The address to get the capability amount
    /// @return The unwrap amount capability
    function getUnwrapCap(address user) external view returns (uint256);

    /// @notice Gets the remaining unwrap allowance for an address
    /// @param user The address to get the remaining of
    /// @return The remaining allowance
    function getRemainingUnwrapAllowance(address user) external view returns (uint256);

    /// @notice Unwraps bUSD0 tokens with cap enforcement
    /// @param amount The amount to unwrap
    function unwrapWithCap(uint256 amount) external;

    /// @notice Gets the current usual distribution per bUSD0
    /// @return The current usual distribution per bUSD0
    function getUsualDistributionPerUsd0pp() external view returns (uint256);

    /// @notice Gets the current duration cost factor
    /// @return The current duration cost factor
    function getDurationCostFactor() external view returns (uint256);

    /// @notice Gets the current accumulated fees
    /// @return The current accumulated fees
    function getAccumulatedFees() external view returns (uint256);

    /// @notice Calculates the required amount of USUAL to burn for early redemption
    /// @param usd0ppAmount The amount of bUSD0 to redeem
    /// @return The required amount of USUAL to burn
    function calculateRequiredUsual(uint256 usd0ppAmount) external view returns (uint256);

    /// @notice Unwraps bUSD0 tokens without cap enforcement
    /// @param amount The amount to unwrap
    function unwrapPegMaintainer(uint256 amount) external;

    /// @notice Reconstructs bUSD0 and rt-USD0 tokens back to USD0 (destroys a bond)
    /// @param amountUsd0pp The amount of bUSD0 to burn for reconstruction
    /// @param assetRecipient The address to receive the returned USD0 tokens
    /// @dev This function burns bUSD0 and rt-USD0 tokens and returns the equivalent USD0
    /// @dev Can only be called when the contract is not paused
    function reconstruct(uint256 amountUsd0pp, address assetRecipient) external;
}
