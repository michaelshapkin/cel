// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IRegistryContract {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice This event is emitted when the address of the contract is set
    /// @param name The name of the contract in bytes32
    /// @param contractAddress The address of the contract
    event SetContract(bytes32 indexed name, address indexed contractAddress);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the address of the contract
    /// @param name The name of the contract in bytes32
    /// @param contractAddress The address of the contract
    function setContract(bytes32 name, address contractAddress) external;

    /// @notice Get the address of the contract
    /// @param name The name of the contract in bytes32
    /// @return contractAddress The address of the contract
    function getContract(bytes32 name) external view returns (address);
}
