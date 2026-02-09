//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IToken {
    function mintLocked(
        address to,
        uint256 amount,
        uint256 timeInWeeks
    ) external;
}
