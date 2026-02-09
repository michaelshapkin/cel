// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IGymSinglePool {
    struct UserInfo {
        uint256 totalDepositTokens;
        uint256 totalDepositDollarValue;
        uint256 level;
        uint256 depositId;
        uint256 totalClaimt;
    }

    function getUserInfo(
        address
    ) external view returns (UserInfo memory);

    function pendingReward(uint256, address) external view returns (uint256);

    function getUserLevelInSinglePool(address) external view returns (uint32);
    function depositFromOtherContract(
        uint256,
        uint8,
        bool,
        address
    ) external;
    function transferFromOldVersion(
        uint256,
        uint8,
        bool,
        address,
        uint256
    ) external;

}