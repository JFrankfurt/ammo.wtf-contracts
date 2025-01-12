// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/AmmoFactory.sol";

contract TestLocalDeploy is Script {
    function setUp() public {
        // Verify we're on the fork
        require(block.chainid == 84532, "Not on Base Testnet fork");
    }

    function run() public {
        // Test entire deployment process
        vm.startBroadcast();

        // Deploy factory
        AmmoFactory factory = new AmmoFactory();
        console.log("Factory deployed at:", address(factory));

        // Test factory functionality
        factory.setFeeDetails(address(0xBEEF), 500);

        // Create a test token
        address tokenAddr = factory.createToken("Test Token", "TEST", 1000 * 10 ** 18);
        console.log("Test token deployed at:", tokenAddr);

        // Test token transfer with fees
        AmmoToken token = AmmoToken(tokenAddr);
        token.transfer(address(0xCAFE), 100 * 10 ** 18);

        // Verify fee collection
        (address feeRecipient,) = factory.getFeeDetails();
        uint256 feeBalance = token.balanceOf(feeRecipient);
        console.log("Fee collected:", feeBalance);

        vm.stopBroadcast();
    }
}
