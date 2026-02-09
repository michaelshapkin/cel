// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ExchangeStorage.sol";

abstract contract OrionVault is ExchangeStorage, ReentrancyGuard, OwnableUpgradeable {
    error NotEnoughBalance();
	enum StakePhase {
		NOTSTAKED,
		LOCKED,
		RELEASING,
		READYTORELEASE,
		FROZEN
	}

	struct Stake {
		uint64 amount; // 100m ORN in circulation fits uint64
		StakePhase phase;
		uint64 lastActionTimestamp;
	}

	uint64 constant releasingDuration = 3600 * 24;
	mapping(address => Stake) private stakingData;

	/**
	 * @dev Returns locked or frozen stake balance only
	 * @param user address
	 */
	function getLockedStakeBalance(address user) public view returns (uint256) {
		return 0;
	}
}
