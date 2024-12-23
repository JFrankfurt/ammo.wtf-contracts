// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20Factory.sol";

contract ERC20FactoryTest is Test {
    ERC20Factory public factory;
    address public owner;
    address public user;
    
    event TokenCreated(address tokenAddress, string name, string symbol);
    
    function setUp() public {
        owner = address(this);
        user = address(0xBAD);
        factory = new ERC20Factory();
    }
    
    function testCreateToken() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 initialSupply = 1000000 * 10**18;
        
        vm.recordLogs();
        address tokenAddress = factory.createToken(name, symbol, initialSupply);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2); // Mint event and TokenCreated event
        
        // Verify the TokenCreated event
        assertEq(entries[1].topics[0], keccak256("TokenCreated(address,string,string)"));
        
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
    
    function testBurnTokens() public {
        uint256 initialSupply = 1000000 * 10**18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        uint256 burnAmount = initialSupply / 2;
        // Approve the tokens first
        token.approve(address(factory), burnAmount);
        factory.burnTokens(tokenAddress, burnAmount);
        
        assertEq(token.balanceOf(address(this)), initialSupply - burnAmount);
    }
    
    function testFailBurnMoreThanBalance() public {
        uint256 initialSupply = 100;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        // Approve first
        token.approve(address(factory), initialSupply + 1);
        factory.burnTokens(tokenAddress, initialSupply + 1);
    }
    
    function testFailBurnNonFactoryToken() public {
        CustomToken standaloneToken = new CustomToken(
            "Standalone",
            "STAND",
            1000000 * 10**18,
            owner
        );
        
        // Approve first
        standaloneToken.approve(address(factory), 100);
        factory.burnTokens(address(standaloneToken), 100);
    }
    
    function testFailBurnTokensAsNonOwner() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000000 * 10**18);
        CustomToken token = CustomToken(tokenAddress);
        
        vm.startPrank(user);
        token.approve(address(factory), 100);
        factory.burnTokens(tokenAddress, 100);
        vm.stopPrank();
    }
    
    function testGetTokenCount() public {
        assertEq(factory.getTokenCount(), 0);
        
        factory.createToken("Token1", "TK1", 1000);
        assertEq(factory.getTokenCount(), 1);
        
        factory.createToken("Token2", "TK2", 1000);
        assertEq(factory.getTokenCount(), 2);
    }
    
    function testGetAllTokens() public {
        address token1 = factory.createToken("Token1", "TK1", 1000);
        address token2 = factory.createToken("Token2", "TK2", 1000);
        address token3 = factory.createToken("Token3", "TK3", 1000);
        
        address[] memory tokens = factory.getAllTokens();
        
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);
    }
    
    function testIsTokenFromFactory() public {
        address factoryToken = factory.createToken("Factory Token", "FT", 1000);
        
        CustomToken standaloneToken = new CustomToken(
            "Standalone",
            "STAND",
            1000,
            owner
        );
        
        assertTrue(factory.isTokenFromFactory(factoryToken));
        assertFalse(factory.isTokenFromFactory(address(standaloneToken)));
    }
    
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
        assertEq(token.balanceOf(address(this)), initialSupply);
    }
    
    function testFuzzBurnTokens(uint256 burnAmount) public {
        uint256 initialSupply = 1000000 * 10**18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);
        
        // Ensure burn amount is not greater than initial supply
        burnAmount = bound(burnAmount, 0, initialSupply);
        
        // Approve the tokens first
        token.approve(address(factory), burnAmount);
        factory.burnTokens(tokenAddress, burnAmount);
        
        assertEq(token.balanceOf(address(this)), initialSupply - burnAmount);
    }
}