// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20Factory.sol";

contract ERC20FactoryTest is Test {
    ERC20Factory public factory;
    address public owner;
    address public user;
    
    // Events to test against
    event TokenCreated(address tokenAddress, string name, string symbol);
    
    function setUp() public {
        // Setup initial test state
        owner = address(this);
        user = address(0xBAD);
        factory = new ERC20Factory();
    }
    
    // ====== Creation Tests ======
    
    function testCreateToken() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 initialSupply = 1000000 * 10**18;
        
        vm.expectEmit(true, false, false, true);
        emit TokenCreated(address(0), name, symbol); // address(0) as we can't predict the exact address
        
        address tokenAddress = factory.createToken(name, symbol, initialSupply);
        
        CustomToken token = CustomToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.balanceOf(owner), initialSupply);
        assertTrue(factory.isTokenFromFactory(tokenAddress));
    }
    
    function testFailCreateTokenAsNonOwner() public {
        vm.prank(user);
        factory.createToken("Test Token", "TEST", 1000000 * 10**18);
    }
    
    // ====== Burning Tests ======
    
    function testBurnTokens() public {
        // First create a token
        uint256 initialSupply = 1000000 * 10**18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        // Test burning half the supply
        uint256 burnAmount = initialSupply / 2;
        factory.burnTokens(tokenAddress, burnAmount);
        
        assertEq(token.balanceOf(owner), initialSupply - burnAmount);
    }
    
    function testFailBurnMoreThanBalance() public {
        // Create token with 100 supply
        uint256 initialSupply = 100;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        
        // Try to burn 101 tokens
        factory.burnTokens(tokenAddress, initialSupply + 1);
    }
    
    function testFailBurnNonFactoryToken() public {
        // Deploy a standalone token (not through factory)
        CustomToken standaloneToken = new CustomToken(
            "Standalone",
            "STAND",
            1000000 * 10**18,
            owner
        );
        
        // Try to burn tokens from non-factory token
        factory.burnTokens(address(standaloneToken), 100);
    }
    
    function testFailBurnTokensAsNonOwner() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000000 * 10**18);
        
        vm.prank(user);
        factory.burnTokens(tokenAddress, 100);
    }
    
    // ====== Getter Function Tests ======
    
    function testGetTokenCount() public {
        assertEq(factory.getTokenCount(), 0);
        
        factory.createToken("Token1", "TK1", 1000);
        assertEq(factory.getTokenCount(), 1);
        
        factory.createToken("Token2", "TK2", 1000);
        assertEq(factory.getTokenCount(), 2);
    }
    
    function testGetAllTokens() public {
        // Create multiple tokens
        address token1 = factory.createToken("Token1", "TK1", 1000);
        address token2 = factory.createToken("Token2", "TK2", 1000);
        address token3 = factory.createToken("Token3", "TK3", 1000);
        
        // Get all tokens
        address[] memory tokens = factory.getAllTokens();
        
        // Verify array contents
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);
    }
    
    // ====== Token Verification Tests ======
    
    function testIsTokenFromFactory() public {
        // Create a token through factory
        address factoryToken = factory.createToken("Factory Token", "FT", 1000);
        
        // Create a standalone token
        CustomToken standaloneToken = new CustomToken(
            "Standalone",
            "STAND",
            1000,
            owner
        );
        
        // Verify factory token
        assertTrue(factory.isTokenFromFactory(factoryToken));
        
        // Verify standalone token is not recognized
        assertFalse(factory.isTokenFromFactory(address(standaloneToken)));
    }
    
    // ====== Fuzz Tests ======
    
    function testFuzzCreateToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 8);
        vm.assume(initialSupply > 0 && initialSupply <= type(uint256).max);
        
        address tokenAddress = factory.createToken(name, symbol, initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.balanceOf(owner), initialSupply);
    }
    
    function testFuzzBurnTokens(uint256 burnAmount) public {
        // Create token with maximum supply
        uint256 initialSupply = type(uint256).max;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        // Ensure burn amount is not greater than initial supply
        vm.assume(burnAmount <= initialSupply);
        
        // Burn tokens
        factory.burnTokens(tokenAddress, burnAmount);
        
        assertEq(token.balanceOf(owner), initialSupply - burnAmount);
    }
}