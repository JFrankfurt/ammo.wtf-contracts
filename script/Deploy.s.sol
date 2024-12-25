// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ERC20Factory.sol";

contract DeployScript is Script {
    // Configuration struct to hold deployment parameters
    struct DeployConfig {
        address initialOwner;
        address initialFeeRecipient;
        uint256 initialFeePercent;
    }

    function run() external {
        // Load configuration
        DeployConfig memory config = getConfig();

        // Deploy contracts
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy factory
        ERC20Factory factory = new ERC20Factory();

        // Configure initial settings
        if (config.initialFeePercent > 0) {
            factory.setFeeDetails(config.initialFeeRecipient, config.initialFeePercent);
        }

        // If owner is different from deployer, transfer ownership
        if (config.initialOwner != address(0) && config.initialOwner != factory.owner()) {
            factory.transferOwnership(config.initialOwner);
        }

        vm.stopBroadcast();

        // Log deployment information
        logDeployment(factory, config);

        // Write deployment addresses to file
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

    function logDeployment(ERC20Factory factory, DeployConfig memory config) internal view {
        console.log("\n-----------------------------------------------");
        console.log("ERC20Factory Deployment Summary");
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

    function saveDeployment(ERC20Factory factory) internal {
        string memory deploymentData = vm.toString(address(factory));
        vm.writeFile("deployment-addresses.txt", deploymentData);
    }
}
