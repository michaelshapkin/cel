// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "../utils/Registry.sol";

contract BBToken is ERC20Upgradeable, ERC20BurnableUpgradeable {
    // =============================================================
    //                           VARIABLES
    // =============================================================
    Registry public registry;
    uint256 maxSupply;

    // =============================================================
    //                          INITIALIZER
    // =============================================================
    function initialize(
        uint256 _initSupply,
        uint256 _maxSupply
    ) public initializer {
        __ERC20_init("BBToken", "BBT");
        __ERC20Burnable_init();
        maxSupply = _maxSupply;
        _mint(msg.sender, _initSupply);
    }

    // =============================================================
    //                          MAIN FUNCTIONS
    // =============================================================
    function mint(address _user, uint256 _amount) public {
        require(_isAuthorizedAddress(msg.sender), "BBToken:: Not authorized");
        _mint(_user, _amount);
    }

    function _isAuthorizedAddress(
        address _address
    ) internal view returns (bool) {
        if (registry.getContractAddress("Savings") == _address) return true;
        if (registry.getContractAddress("Referral") == _address) return true;
        if (registry.getContractAddress("Insurance") == _address) return true;
        if (registry.getContractAddress("Income") == _address) return true;
        if (registry.getContractAddress("LockedSavings") == _address)
            return true;

        revert("BBToken: Not Registered");
    }

    // =============================================================
    //                            SETTERS
    // =============================================================
    function setRegistry(address _registry) external {
        registry = Registry(_registry);
    }

    function setMaxSupply(uint256 _amount) external {
        require(
            msg.sender == 0xb0Ab5d6F8e99C07Fa4965524bbe9C57D9eD35a38,
            "Not authorized"
        );

        maxSupply = _amount;
    }

    // =============================================================
    //                           OVERRIDE
    // =============================================================
    function name() public view override returns (string memory) {
        return "BloomBeans";
    }

    function symbol() public view override returns (string memory) {
        return "BEAN";
    }
}
