// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/AmmoFactory.sol";

contract DeployScript is Script {
    struct DeployConfig {
        address initialOwner;
        address initialFeeRecipient;
        uint256 initialFeePercent;
    }

    function run() external {
        DeployConfig memory config = getConfig();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy factory
        AmmoFactory factory = new AmmoFactory();

        // Configure initial settings
        if (config.initialFeePercent > 0) {
            factory.setFeeDetails(config.initialFeeRecipient, config.initialFeePercent);
        }

        // If owner is different from deployer, transfer ownership
        if (config.initialOwner != address(0) && config.initialOwner != factory.owner()) {
            factory.transferOwnership(config.initialOwner);
        }

        vm.stopBroadcast();

        logDeployment(factory, config);
        saveDeployment(factory);
    }

    function getConfig() internal view returns (DeployConfig memory) {
        // Load from environment or use defaults
        DeployConfig memory config;

        // Initial owner (optional, defaults to deployer)
        try vm.envAddress("INITIAL_OWNER") returns (address owner) {
            config.initialOwner = owner;
        } catch {
            config.initialOwner = address(0);
        }

        // Initial fee recipient (optional)
        try vm.envAddress("INITIAL_FEE_RECIPIENT") returns (address recipient) {
            config.initialFeeRecipient = recipient;
        } catch {
            config.initialFeeRecipient = address(0);
        }

        // Initial fee percent (optional, in basis points)
        try vm.envUint("INITIAL_FEE_PERCENT") returns (uint256 fee) {
            require(fee <= 1000, "Fee cannot exceed 10%");
            config.initialFeePercent = fee;
        } catch {
            config.initialFeePercent = 0;
        }

        return config;
    }

    function logDeployment(AmmoFactory factory, DeployConfig memory config) internal view {
        console.log("\n-----------------------------------------------");
        console.log("AmmoFactory Deployment Summary");
        console.log("-----------------------------------------------");
        console.log("Factory address:", address(factory));
        console.log("Owner:", factory.owner());
        console.log("Initial owner configured:", config.initialOwner);
        (address feeRecipient, uint256 feePercent) = factory.getFeeDetails();
        console.log("Fee recipient:", feeRecipient);
        console.log("Fee percent (basis points):", feePercent);
        console.log("Initial fee recipient configured:", config.initialFeeRecipient);
        console.log("Initial fee percent configured:", config.initialFeePercent);
        console.log("-----------------------------------------------\n");
    }

    function saveDeployment(AmmoFactory factory) internal {
        string memory deploymentData = vm.toString(address(factory));
        vm.writeFile("deployment-addresses.txt", deploymentData);
    }
}
