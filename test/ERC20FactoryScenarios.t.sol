// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AmmoFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error OwnableUnauthorizedAccount(address account);

contract AmmoFactoryScenarioTest is Test {
    AmmoFactory public factory;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0xBAD1);
        user2 = address(0xBAD2);

        factory = new AmmoFactory();

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testComplexTokenLifecycle() public {
        // Create multiple tokens
        address token1 = factory.createToken("Token1", "TK1", 1000000);
        address token2 = factory.createToken("Token2", "TK2", 2000000);

        AmmoToken tk1 = AmmoToken(token1);
        AmmoToken tk2 = AmmoToken(token2);

        // Transfer some tokens to users
        tk1.transfer(user1, 100000);
        tk1.transfer(user2, 200000);
        tk2.transfer(user1, 150000);

        // Verify balances
        assertEq(tk1.balanceOf(user1), 100000);
        assertEq(tk1.balanceOf(user2), 200000);
        assertEq(tk2.balanceOf(user1), 150000);

        // Burn some tokens
        uint256 burnAmount = 50000;
        tk1.approve(address(factory), burnAmount);
        factory.burnTokens(token1, burnAmount);

        // Verify total supply decreased
        assertEq(tk1.totalSupply(), 1000000 - burnAmount);

        // Try transferring between users
        vm.startPrank(user1);
        tk1.transfer(user2, 50000);
        vm.stopPrank();

        assertEq(tk1.balanceOf(user1), 50000);
        assertEq(tk1.balanceOf(user2), 250000);
    }

    function testStressTest() public {
        // Create an array to store token addresses
        address[] memory tokens = new address[](5);

        // Create multiple tokens
        for (uint256 i = 0; i < 5; i++) {
            string memory name = string(abi.encodePacked("Token", vm.toString(i)));
            string memory symbol = string(abi.encodePacked("TK", vm.toString(i)));
            tokens[i] = factory.createToken(name, symbol, 1000000 * (i + 1));
        }

        // Perform multiple operations
        for (uint256 i = 0; i < tokens.length; i++) {
            AmmoToken token = AmmoToken(tokens[i]);

            // Transfer to users
            token.transfer(user1, 100000);
            token.transfer(user2, 200000);

            // Approve and burn
            token.approve(address(factory), 50000);
            factory.burnTokens(tokens[i], 50000);

            // Verify state
            assertTrue(factory.isTokenFromFactory(tokens[i]));
            assertEq(token.balanceOf(user1), 100000);
            assertEq(token.balanceOf(user2), 200000);
            assertEq(token.balanceOf(address(this)), (1000000 * (i + 1)) - 350000); // initial - transfers - burned
        }
    }

    function testFailureRecovery() public {
        // Create a token
        address tokenAddr = factory.createToken("Token", "TK", 1000000);
        AmmoToken token = AmmoToken(tokenAddr);

        // Try to burn more than balance - this should revert with specific error
        vm.expectRevert("ERC20: insufficient balance");
        token.approve(address(factory), 2000000);
        factory.burnTokens(tokenAddr, 2000000);

        // Verify state is unchanged
        assertEq(token.totalSupply(), 1000000);

        // Now do a valid burn
        token.approve(address(factory), 500000);
        factory.burnTokens(tokenAddr, 500000);

        // Verify the burn worked
        assertEq(token.totalSupply(), 500000);
        assertEq(token.balanceOf(address(this)), 500000);
    }

    function testOwnershipAndMinting() public {
        // Create token as owner
        address tokenAddr = factory.createToken("TestToken", "TTK", 1000000);
        AmmoToken token = AmmoToken(tokenAddr);

        // Verify initial ownership
        assertEq(token.owner(), owner);

        // Try to create token as non-owner
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        factory.createToken("FailToken", "FAIL", 1000000);
        vm.stopPrank();

        // Try to mint as non-owner
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        token.mint(user1, 100000);
        vm.stopPrank();

        // Mint as owner should succeed
        uint256 initialSupply = token.totalSupply();
        token.mint(owner, 500000);
        assertEq(token.totalSupply(), initialSupply + 500000);
        assertEq(token.balanceOf(owner), initialSupply + 500000);

        // Transfer ownership to user1
        token.transferOwnership(user1);
        assertEq(token.owner(), user1);

        // Previous owner should no longer be able to mint
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, owner));
        token.mint(owner, 100000);

        // New owner should be able to mint
        vm.startPrank(user1);
        token.mint(user1, 100000);
        vm.stopPrank();
        assertEq(token.balanceOf(user1), 100000);
    }
}
