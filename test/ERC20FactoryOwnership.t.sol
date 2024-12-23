// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/ERC20Factory.sol";

contract ERC20FactoryOwnershipTest is Test {
    ERC20Factory public factory;
    address public owner;
    address public newOwner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function setUp() public {
        owner = address(this);
        newOwner = address(0xBEEF);
        factory = new ERC20Factory();
    }
    
    function testCannotRenounceOwnership() public {
        vm.expectRevert("Ownership cannot be renounced");
        factory.renounceOwnership();
    }
    
    function testOwnershipTransfer() public {
        // Verify initial owner
        assertEq(factory.owner(), owner);
        
        // Transfer ownership
        factory.transferOwnership(newOwner);
        
        // Verify new owner
        assertEq(factory.owner(), newOwner);
        
        // Verify old owner can't call onlyOwner functions
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        factory.createToken("Test", "TST", 1000);
        
        // New owner can call onlyOwner functions
        vm.prank(newOwner);
        address tokenAddr = factory.createToken("Test", "TST", 1000);
        assertTrue(factory.isTokenFromFactory(tokenAddr));
    }
    
    function testFailTransferToZeroAddress() public {
        vm.expectRevert("Ownable: new owner is the zero address");
        factory.transferOwnership(address(0));
    }
    
    function testTransferOwnershipEvents() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        factory.transferOwnership(newOwner);
    }
}