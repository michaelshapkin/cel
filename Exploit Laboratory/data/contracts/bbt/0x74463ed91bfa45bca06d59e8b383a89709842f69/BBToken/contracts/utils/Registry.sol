// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Registry is OwnableUpgradeable {
    mapping(string => address) public registry;
    mapping(address => bool) public registered;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function setContractAddress(
        string memory _name,
        address _address
    ) external onlyOwner {
        registry[_name] = _address;
        registered[_address] = true;
    }

    function getContractAddress(
        string memory _name
    ) external view returns (address) {
        require(
            registry[_name] != address(0),
            string(abi.encodePacked("Registry: Does not exist", _name))
        );
        return registry[_name];
    }

    function isRegistered(address _address) external view returns (bool) {
        return registered[_address];
    }
}
