// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FlawVerifier} from "../src/FlawVerifier.sol";

contract FlawVerifierTest is Test {
    function pad4(uint256 n) internal pure returns (string memory) {
        string memory s = vm.toString(n);
        if (bytes(s).length == 4) return s;
        if (bytes(s).length == 3) return string.concat("0", s);
        if (bytes(s).length == 2) return string.concat("00", s);
        if (bytes(s).length == 1) return string.concat("000", s);
        return s; 
    }

    function testVerifyFlaw() public {
        uint256 initialBalance = 1_000_000 ether;
        vm.deal(address(this), initialBalance);
        
        FlawVerifier flawVerifier = new FlawVerifier{value: initialBalance}();

        console.log("Initial balance:", initialBalance / 1 ether, "ETH");
        
        flawVerifier.executeOnOpportunity();
        
        uint256 finalBalance = address(flawVerifier).balance;
        uint256 fbWhole = finalBalance / 1 ether;
        uint256 fbFrac  = (finalBalance % 1 ether) / 1e14;
        
        console.log(
            string.concat(
                "Final balance: ",
                vm.toString(fbWhole), ".",
                pad4(fbFrac),
                " ETH"
            )
        );

        require(finalBalance >= 1_000_000.1 ether, "Profit too low or loss occurred");
    }
}
