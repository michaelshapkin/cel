// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {
    ReentrancyGuardUpgradeable
} from "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ERC20Upgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {
    ERC20PermitUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {IUsd0PP} from "src/interfaces/token/IUsd0PP.sol";
import {IUsd0} from "./../interfaces/token/IUsd0.sol";
import {IRTUsd0} from "./../interfaces/token/IRTUsd0.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {IUsual} from "src/interfaces/token/IUsual.sol";
import {Approval as PermitApproval} from "src/interfaces/IDaoCollateral.sol";

import {
    CONTRACT_YIELD_TREASURY,
    DEFAULT_ADMIN_ROLE,
    FLOOR_PRICE_UPDATER_ROLE,
    BOND_DURATION_FOUR_YEAR,
    PAUSING_CONTRACTS_ROLE,
    PEG_MAINTAINER_UNLIMITED_ROLE,
    UNWRAP_CAP_ALLOCATOR_ROLE,
    USD0PP_CAPPED_UNWRAP_ROLE,
    USD0PP_USUAL_DISTRIBUTION_ROLE,
    USD0PP_DURATION_COST_FACTOR_ROLE,
    FEE_SWEEPER_ROLE,
    CONTRACT_DISTRIBUTION_MODULE,
    SCALAR_ONE,
    BUSD0Symbol,
    BUSD0Name
} from "src/constants.sol";

import {
    BondNotStarted,
    BondFinished,
    BondNotFinished,
    NotAuthorized,
    AmountIsZero,
    NullAddress,
    Blacklisted,
    AmountTooBig,
    FloorPriceTooHigh,
    AmountMustBeGreaterThanZero,
    InsufficientUsd0ppBalance,
    FloorPriceNotSet,
    UnwrapCapNotSet,
    AmountTooBigForCap,
    UsualAmountTooLow,
    UsualAmountIsZero
} from "src/errors.sol";

/// @title   Usd0PP Contract
/// @notice  Manages bond-like financial instruments for the UsualDAO ecosystem, providing functionality for minting, transferring, and unwrapping bonds.
/// @dev     Inherits from ERC20, ERC20PermitUpgradeable, and ReentrancyGuardUpgradeable to provide a range of functionalities along with protections against reentrancy attacks.
/// @dev     This contract is upgradeable, allowing for future improvements and enhancements.
/// @author  Usual Tech team

contract Usd0PP is
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable,
    IUsd0PP
{
    using CheckAccessControl for IRegistryAccess;
    using SafeERC20 for IERC20;
    using SafeERC20 for IUsual;

    /// @custom:storage-location erc7201:Usd0PP.storage.v0
    struct Usd0PPStorageV0 {
        /// The start time of the bond period.
        uint256 bondStart;
        /// The address of the registry contract.
        IRegistryContract registryContract;
        /// The address of the registry access contract.
        IRegistryAccess registryAccess;
        /// The USD0 token.
        IERC20 usd0;
        uint256 unusedBondEarlyUnlockStart;
        uint256 unusedBondEarlyUnlockEnd;
        mapping(address => uint256) unusedBondEarlyUnlockAllowedAmount;
        mapping(address => bool) unusedBondEarlyUnlockDisabled;
        /// The current floor price for unlocking bUSD0 to USD0 (18 decimal places)
        uint256 floorPrice;
        /// The USUAL token
        IUsual usual;
        /// Tracks daily bUSD0 inflows
        mapping(uint256 => uint256) unusedDailyUsd0ppInflows;
        /// Tracks daily bUSD0 outflows
        mapping(uint256 => uint256) unusedDailyUsd0ppOutflows;
        /// USUAL distributed per bUSD0 per day (18 decimal places)
        uint256 usualDistributionPerUsd0pp;
        /// The percentage of burned USUAL that goes to the treasury (basis points), no longer used, kept for storage slot ordering purpose
        uint256 unusedTreasuryAllocationRate;
        /// Daily redemption target rate (basis points of total supply)
        uint256 unusedTargetRedemptionRate;
        /// Duration cost adjustment factor in days
        uint256 durationCostFactor;
        /// Mapping of addresses to their unwrap cap
        mapping(address => uint256) unwrapCaps;
        /// Accumulated fees in USUAL
        uint256 accumulatedFees;
        /// The RTUSD0 token
        IRTUsd0 rtusd0;
    }

    // keccak256(abi.encode(uint256(keccak256("Usd0PP.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant Usd0PPStorageV0Location =
        0x1519c21cc5b6e62f5c0018a7d32a0d00805e5b91f6eaa9f7bc303641242e3000;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _usd0ppStorageV0() internal pure returns (Usd0PPStorageV0 storage $) {
        bytes32 position = Usd0PPStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             Initializer
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the bUSD0 contract
    /// @param rtusd0 contract address of the bUSD0 redemption token
    function initializeV3(address rtusd0) public reinitializer(4) {
        // Initialize parent contracts
        __ERC20_init(BUSD0Name, BUSD0Symbol);
        __ERC20Permit_init(BUSD0Name);

        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        $.rtusd0 = IRTUsd0(rtusd0);
    }

    /*//////////////////////////////////////////////////////////////
                             External Functions
    //////////////////////////////////////////////////////////////*/

    // @inheritdoc IUsd0PP
    function pause() public {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(PAUSING_CONTRACTS_ROLE);
        _pause();
    }

    // @inheritdoc IUsd0PP
    function unpause() external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _unpause();
    }

    // @inheritdoc IUsd0PP
    function mint(uint256 amountUsd0) external nonReentrant whenNotPaused {
        _deconstruct(amountUsd0, msg.sender, msg.sender);
    }

    // @inheritdoc IUsd0PP
    function mint(uint256 amountUsd0, address bAssetRecipient, address rAssetRecipient)
        external
        nonReentrant
        whenNotPaused
    {
        if (bAssetRecipient == address(0) || rAssetRecipient == address(0)) {
            revert NullAddress();
        }
        _deconstruct(amountUsd0, bAssetRecipient, rAssetRecipient);
    }

    // @inheritdoc IUsd0PP
    function mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        try IERC20Permit(address($.usd0))
            .permit(msg.sender, address(this), amountUsd0, deadline, v, r, s) {}
            catch {} // solhint-disable-line no-empty-blocks

        _deconstruct(amountUsd0, msg.sender, msg.sender);
    }

    // @inheritdoc IUsd0PP
    function unwrap() external nonReentrant whenNotPaused {
        _unwrap(msg.sender);
    }

    // @inheritdoc IUsd0PP
    function unwrap(address assetRecipient) external nonReentrant whenNotPaused {
        if (assetRecipient == address(0)) {
            revert NullAddress();
        }
        _unwrap(assetRecipient);
    }

    // @inheritdoc IUsd0PP
    function setUnwrapCap(address user, uint256 cap) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(UNWRAP_CAP_ALLOCATOR_ROLE);

        $.unwrapCaps[user] = cap;
        emit UnwrapCapSet(user, cap);
    }

    // @inheritdoc IUsd0PP
    function unwrapWithCap(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert AmountIsZero();
        }

        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        $.registryAccess.onlyMatchingRole(USD0PP_CAPPED_UNWRAP_ROLE);

        // Check cap is set
        if ($.unwrapCaps[msg.sender] == 0) {
            revert UnwrapCapNotSet();
        }

        if (amount > $.unwrapCaps[msg.sender]) {
            revert AmountTooBigForCap();
        }

        $.unwrapCaps[msg.sender] -= amount;

        _burn(msg.sender, amount);
        $.usd0.safeTransfer(msg.sender, amount);

        emit CappedUnwrap(msg.sender, amount, $.unwrapCaps[msg.sender]);
    }

    // @inheritdoc IUsd0PP
    function unwrapPegMaintainer(uint256 amount) external nonReentrant whenNotPaused {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        $.registryAccess.onlyMatchingRole(PEG_MAINTAINER_UNLIMITED_ROLE);
        // revert if the bond period has not started
        if (block.timestamp < $.bondStart) {
            revert BondNotStarted();
        }
        uint256 usd0PPBalance = balanceOf(msg.sender);
        if (usd0PPBalance < amount) {
            revert AmountTooBig();
        }
        _burn(msg.sender, amount);

        $.usd0.safeTransfer(msg.sender, amount);

        emit BondUnwrapped(msg.sender, amount);
    }

    /// @inheritdoc IUsd0PP
    function emergencyWithdraw(address safeAccount) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        if (!$.registryAccess.hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized();
        }
        IERC20 usd0 = $.usd0;

        uint256 balance = usd0.balanceOf(address(this));
        // get the collateral token for the bond
        usd0.safeTransfer(safeAccount, balance);

        // Pause the contract
        if (!paused()) {
            _pause();
        }

        emit EmergencyWithdraw(safeAccount, balance);
    }

    // @inheritdoc IUsd0PP
    function updateFloorPrice(uint256 newFloorPrice) external {
        if (newFloorPrice > 1e18) {
            revert FloorPriceTooHigh();
        }
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(FLOOR_PRICE_UPDATER_ROLE);

        $.floorPrice = newFloorPrice;

        emit FloorPriceUpdated(newFloorPrice);
    }

    // @inheritdoc IUsd0PP
    function unlockUsd0ppFloorPrice(uint256 usd0ppAmount) external nonReentrant whenNotPaused {
        if (usd0ppAmount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (balanceOf(msg.sender) < usd0ppAmount) {
            revert InsufficientUsd0ppBalance();
        }
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        if ($.floorPrice == 0) {
            revert FloorPriceNotSet();
        }

        // as floorPrice can't be greater than 1e18, we will never have a usd0Amount greater than the usd0 backing
        uint256 usd0Amount = Math.mulDiv(usd0ppAmount, $.floorPrice, 1e18, Math.Rounding.Floor);

        _burn(msg.sender, usd0ppAmount);
        $.usd0.safeTransfer(msg.sender, usd0Amount);

        // Calculate and transfer the delta to the treasury
        uint256 delta = usd0ppAmount - usd0Amount;
        if (delta > 0) {
            address treasury = $.registryContract.getContract(CONTRACT_YIELD_TREASURY);
            $.usd0.safeTransfer(treasury, delta);
        }

        emit Usd0ppUnlockedFloorPrice(msg.sender, usd0ppAmount, usd0Amount);
    }

    // @inheritdoc IUsd0PP
    function unlockUSD0ppWithUsual(uint256 usd0ppAmount, uint256 maxUsualAmount)
        public
        nonReentrant
        whenNotPaused
    {
        uint256 requiredUsual = calculateRequiredUsual(usd0ppAmount);
        if (requiredUsual == 0) {
            revert UsualAmountIsZero();
        }
        if (requiredUsual > maxUsualAmount) {
            revert UsualAmountTooLow();
        }

        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        $.usual.safeTransferFrom(msg.sender, address(this), requiredUsual);

        // Update accumulated USUAL
        $.accumulatedFees += requiredUsual;

        _burn(msg.sender, usd0ppAmount);
        $.usd0.safeTransfer(msg.sender, usd0ppAmount);

        emit BondUnwrappedEarlyWithUsualBurn(msg.sender, usd0ppAmount);
    }

    // @inheritdoc IUsd0PP
    function unlockUSD0ppWithUsualWithPermit(
        uint256 usd0ppAmount,
        uint256 maxUsualAmount,
        PermitApproval calldata usualApproval,
        PermitApproval calldata usd0ppApproval
    ) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // Execute the USUAL permit
        try IERC20Permit(address($.usual))
            .permit(
                msg.sender,
                address(this),
                maxUsualAmount,
                usualApproval.deadline,
                usualApproval.v,
                usualApproval.r,
                usualApproval.s
            ) {}
            catch {} // solhint-disable-line no-empty-blocks

        (usd0ppApproval); // to avoid compiler warning
        // Call the standard unlock function
        unlockUSD0ppWithUsual(usd0ppAmount, maxUsualAmount);
    }

    // @inheritdoc IUsd0PP
    function sweepFees() external nonReentrant returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(FEE_SWEEPER_ROLE);
        address distributionModule = $.registryContract.getContract(CONTRACT_DISTRIBUTION_MODULE);
        uint256 accumulatedFees = $.accumulatedFees;
        if (accumulatedFees == 0) {
            return 0;
        }

        $.accumulatedFees = 0;
        $.usual.safeTransfer(distributionModule, accumulatedFees);
        emit FeeSwept(msg.sender, distributionModule, accumulatedFees);
        return accumulatedFees;
    }

    // @inheritdoc IUsd0PP
    function setUsualDistributionPerUsd0pp(uint256 newRate) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(USD0PP_USUAL_DISTRIBUTION_ROLE);

        if (newRate == 0) {
            revert AmountIsZero();
        }

        $.usualDistributionPerUsd0pp = newRate;
        emit UsualDistributionPerUsd0ppSet(newRate);
    }

    // @inheritdoc IUsd0PP
    function setDurationCostFactor(uint256 newFactor) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(USD0PP_DURATION_COST_FACTOR_ROLE);

        if (newFactor == 0) {
            revert AmountIsZero();
        }

        $.durationCostFactor = newFactor;
        emit DurationCostFactorSet(newFactor);
    }

    // @inheritdoc IUsd0PP
    function reconstruct(uint256 amountUsd0pp, address assetRecipient)
        external
        nonReentrant
        whenNotPaused
    {
        if (amountUsd0pp == 0) {
            revert AmountIsZero();
        }
        if (assetRecipient == address(0)) {
            revert NullAddress();
        }
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // burn the bUSD0 bond tokens from the sender's balance
        // this effectively destroys the bond position
        // no input check as the burn will revert if there is not enough funds
        _burn(msg.sender, amountUsd0pp);

        // burn the rt-USD0 redemption tokens from the sender's balance
        // these tokens represent the right to redeem the bond
        $.rtusd0.burnFrom(msg.sender, amountUsd0pp);

        // transfer the underlying USD0 collateral back to the specified recipient
        // this completes the reconstruction process by returning the original collateral
        $.usd0.safeTransfer(assetRecipient, amountUsd0pp);

        emit Reconstructed(msg.sender, amountUsd0pp, assetRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                             View Functions
    //////////////////////////////////////////////////////////////*/

    // @inheritdoc IUsd0PP
    function totalBondTimes() public pure returns (uint256) {
        return BOND_DURATION_FOUR_YEAR;
    }

    // @inheritdoc IUsd0PP
    function getStartTime() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.bondStart;
    }

    // @inheritdoc IUsd0PP
    function getEndTime() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.bondStart + BOND_DURATION_FOUR_YEAR;
    }

    // @inheritdoc IUsd0PP
    function getFloorPrice() external view returns (uint256) {
        return _usd0ppStorageV0().floorPrice;
    }

    // @inheritdoc IUsd0PP
    function getUnwrapCap(address user) external view returns (uint256) {
        return _usd0ppStorageV0().unwrapCaps[user];
    }

    // @inheritdoc IUsd0PP
    function getRemainingUnwrapAllowance(address user) external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.unwrapCaps[user];
    }

    // @inheritdoc IUsd0PP
    function getDurationCostFactor() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.durationCostFactor;
    }

    // @inheritdoc IUsd0PP
    function getUsualDistributionPerUsd0pp() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.usualDistributionPerUsd0pp;
    }

    // @inheritdoc IUsd0PP
    function getAccumulatedFees() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.accumulatedFees;
    }

    // @inheritdoc IUsd0PP
    function calculateRequiredUsual(uint256 usd0ppAmount) public view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // Simplified calculation: amount * duration factor * distribution rate
        return Math.mulDiv(
            usd0ppAmount * $.durationCostFactor,
            $.usualDistributionPerUsd0pp,
            SCALAR_ONE,
            Math.Rounding.Ceil
        );
    }

    /*//////////////////////////////////////////////////////////////
                             Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _update(address sender, address recipient, uint256 amount)
        internal
        override(ERC20PausableUpgradeable, ERC20Upgradeable)
    {
        if (amount == 0) {
            revert AmountIsZero();
        }
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        IUsd0 usd0 = IUsd0(address($.usd0));
        if (usd0.isBlacklisted(sender) || usd0.isBlacklisted(recipient)) {
            revert Blacklisted();
        }
        // we update the balance of the sender and the recipient
        super._update(sender, recipient, amount);
    }

    function _deconstruct(uint256 amountUsd0, address bAssetRecipient, address rAssetRecipient)
        internal
    {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        if (amountUsd0 == 0) {
            revert AmountIsZero();
        }

        // revert if the bond period is finished
        if (block.timestamp >= $.bondStart + BOND_DURATION_FOUR_YEAR) {
            revert BondFinished();
        }

        // get the collateral token for the bond
        $.usd0.safeTransferFrom(msg.sender, address(this), amountUsd0);

        // mint the bond token for the specified recipient
        _mint(bAssetRecipient, amountUsd0);

        // mint the redemption token for the specified recipient
        $.rtusd0.mint(rAssetRecipient, amountUsd0);

        emit Deconstructed(msg.sender, amountUsd0, bAssetRecipient, rAssetRecipient);
    }

    function _unwrap(address assetRecipient) internal {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // revert if the bond period is not finished
        if (block.timestamp < $.bondStart + BOND_DURATION_FOUR_YEAR) {
            revert BondNotFinished();
        }
        uint256 usd0PPBalance = balanceOf(msg.sender);

        _burn(msg.sender, usd0PPBalance);

        $.usd0.safeTransfer(assetRecipient, usd0PPBalance);

        emit BondUnwrapped(msg.sender, usd0PPBalance, assetRecipient);
    }
}
