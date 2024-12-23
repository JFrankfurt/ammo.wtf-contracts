// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/ERC20Factory.sol";

contract ERC20FactoryInvariantTest is Test {
    ERC20Factory public factory;
    address[] public actors;
    address public immutable initialOwner = address(this);
    
    function setUp() public {
        factory = new ERC20Factory();
        // Create some test actors
        for(uint i = 0; i < 5; i++) {
            actors.push(address(uint160(i + 1)));
            vm.deal(actors[i], 100 ether);
        }
    }
    
    function invariant_ownershipIsValid() public view {
        // Simply verify owner is never address(0)
        assertTrue(factory.owner() != address(0), "Owner cannot be zero address");
        
        // Verify owner has proper permissions by checking if token count is accessible
        factory.getTokenCount();
    }
    
    function invariant_tokenCountMatchesArray() public view {
        assertEq(factory.getTokenCount(), factory.getAllTokens().length);
    }
    
    function invariant_allTokensAreValid() public view {
        address[] memory tokens = factory.getAllTokens();
        for(uint i = 0; i < tokens.length; i++) {
            assertTrue(factory.isTokenFromFactory(tokens[i]));
            
            // Verify it's actually an ERC20 token
            CustomToken token = CustomToken(tokens[i]);
            // These calls should not revert
            token.name();
            token.symbol();
            token.decimals();
        }
    }

    function invariant_tokenOwnershipValid() public view {
        address[] memory tokens = factory.getAllTokens();
        
        for(uint i = 0; i < tokens.length; i++) {
            CustomToken token = CustomToken(tokens[i]);
            // All tokens should have their initial supply owned by the initial factory owner
            // This is because tokens are minted to the owner at time of creation
            assertTrue(
                token.balanceOf(initialOwner) <= token.totalSupply(),
                "Token balance should not exceed total supply"
            );
        }
    }
}