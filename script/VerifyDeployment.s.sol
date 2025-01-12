// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/AmmoFactory.sol";

contract VerifyDeployment is Script {
    function run() external view {
        // Load deployed addresses
        string memory deployedAddresses = vm.readFile("deployment-addresses.txt");
        address factory = vm.parseAddress(deployedAddresses);

        // Verify factory
        AmmoFactory deployedFactory = AmmoFactory(factory);

        // Verify owner
        require(deployedFactory.owner() == vm.envAddress("INITIAL_OWNER"), "Owner mismatch");

        // Verify fee settings
        (address feeRecipient, uint256 feePercent) = deployedFactory.getFeeDetails();
        require(feeRecipient == vm.envAddress("INITIAL_FEE_RECIPIENT"), "Fee recipient mismatch");
        require(feePercent == vm.envUint("INITIAL_FEE_PERCENT"), "Fee percent mismatch");

        console.log("All post-deployment checks passed!");
    }
}
