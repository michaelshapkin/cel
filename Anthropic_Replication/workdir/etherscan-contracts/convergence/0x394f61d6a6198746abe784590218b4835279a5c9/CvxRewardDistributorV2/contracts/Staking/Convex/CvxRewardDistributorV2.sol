// SPDX-License-Identifier: MIT
/**
 _____
/  __ \
| /  \/ ___  _ ____   _____ _ __ __ _  ___ _ __   ___ ___
| |    / _ \| '_ \ \ / / _ \ '__/ _` |/ _ \ '_ \ / __/ _ \
| \__/\ (_) | | | \ V /  __/ | | (_| |  __/ | | | (_|  __/
 \____/\___/|_| |_|\_/ \___|_|  \__, |\___|_| |_|\___\___|
                                 __/ |
                                |___/
 */

/// @title Cvg-Finance - CvxRewardDistributor
/// @notice Receives all Convex rewards from CvgCVX.
/// @dev Optimize gas cost on claim on several contract by limiting ERC20 transfers.
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/Convex/ICvxStakingPositionService.sol";

import "../../interfaces/ICvgControlTowerV2.sol";
import "../../interfaces/ICvg.sol";
import "../../interfaces/ICrvPoolPlain.sol";
import "../../interfaces/Convex/ICvxLocker.sol";
import "../../interfaces/Convex/ICvgCVX.sol";
import "../../interfaces/Convex/ICVX1.sol";

contract CvxRewardDistributorV2 is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev Convergence control tower
    ICvgControlTowerV2 public constant cvgControlTower = ICvgControlTowerV2(0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7);

    /// @dev Convex token
    IERC20 public constant CVX = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    /// @dev Convergence token
    ICvg public constant CVG = ICvg(0x97efFB790f2fbB701D88f89DB4521348A2B77be8);

    /// @notice Cvx Convergence Locker contract
    ICvgCVX public cvgCVX;

    /// @notice cvgCVX/CVX1 stable pool contract on Curve
    ICrvPoolPlain public poolCvgCvxCvx1;

    /// @dev CVX1 contract
    ICVX1 public cvx1;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Distribute Convex rewards for a receiver, owner of a Staking Position
     * @dev    Function used when only one account and contract are involved for a claiming.
     * @param receiver                  Receiver of the rewards.
     * @param totalCvgClaimable         Useless param now
     * @param totalCvxRewardsClaimable  List of tokenAmount to wihtdraw for the user.
     * @param minCvgCvxAmountOut        If greater than 0, converts all CVX into cvgCVX. Minimum amount to receive.
     * @param isConvert                 If true, converts all CVX into cvgCVX.
     */
    function claimCvgCvxSimple(
        address receiver,
        uint256 totalCvgClaimable,
        ICommonStruct.TokenAmount[] memory totalCvxRewardsClaimable,
        uint256 minCvgCvxAmountOut,
        bool isConvert
    ) external {
        require(cvgControlTower.isStakingContract(msg.sender), "NOT_STAKING");
        _withdrawRewards(receiver, totalCvxRewardsClaimable, minCvgCvxAmountOut, isConvert);
    }

    /** @dev Mint accumulated Transfers Cvonex rewards to the claimer of Stakings
     *  @param receiver                 Receiver of the claim
     *  @param totalCvxRewardsClaimable Array of all Convex rewards to send to the receiver
     *  @param minCvgCvxAmountOut       Minimum amount of cvgCVX to receive in case of a pool exchange
     *  @param isConvert                If true, converts all CVX into cvgCVX.
     *
     */
    function _withdrawRewards(
        address receiver,
        ICommonStruct.TokenAmount[] memory totalCvxRewardsClaimable,
        uint256 minCvgCvxAmountOut,
        bool isConvert
    ) internal {
        for (uint256 i; i < totalCvxRewardsClaimable.length; ) {
            uint256 rewardAmount = totalCvxRewardsClaimable[i].amount;

            if (rewardAmount > 0) {
                /// @dev If the token is CVX & we want to convert it in cvgCVX
                if (isConvert && totalCvxRewardsClaimable[i].token == CVX) {
                    if (minCvgCvxAmountOut == 0) {
                        /// @dev Mint cvgCVX 1:1 via cvgCVX contract
                        cvgCVX.mint(receiver, rewardAmount, false);
                    }
                    /// @dev Else it's a swap
                    else {
                        cvx1.mint(address(this), rewardAmount);
                        poolCvgCvxCvx1.exchange(0, 1, rewardAmount, minCvgCvxAmountOut, receiver);
                    }
                }
                /// @dev Else transfer the ERC20 to the receiver
                else {
                    totalCvxRewardsClaimable[i].token.safeTransfer(receiver, rewardAmount);
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @notice Set the cvgCVX/CVX1 stable pool. Approve CVX1 tokens to be transferred from the cvgCVX LP.
     *  @dev    The approval has to be done to perform swaps from CVX1 to cvgCVX during claims.
     *  @param _poolCvgCvxCvx1 Address of the cvgCVX/CVX1 stable pool to set
     */
    function setPoolCvgCvxCvx1AndApprove(ICrvPoolPlain _poolCvgCvxCvx1) external onlyOwner {
        /// @dev Remove approval from previous pool
        if (address(poolCvgCvxCvx1) != address(0)) {
            cvx1.approve(address(poolCvgCvxCvx1), 0);
        }

        poolCvgCvxCvx1 = _poolCvgCvxCvx1;
        cvx1.approve(address(_poolCvgCvxCvx1), type(uint256).max);
    }
}
