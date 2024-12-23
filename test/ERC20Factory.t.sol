// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20Factory.sol";

contract ERC20FactoryTest is Test {
    ERC20Factory public factory;
    address public owner;
    address public user;
    address public feeRecipient;

    event TokenCreated(address tokenAddress, string name, string symbol);
    event FeeUpdated(address recipient, uint256 feePercent);

    function setUp() public {
        owner = address(this);
        user = address(0xBAD);
        feeRecipient = address(0xF33);
        factory = new ERC20Factory();
    }

    function testCreateToken() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 initialSupply = 1000000 * 10 ** 18;

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
        factory.createToken("Test Token", "TEST", 1000000 * 10 ** 18);
    }

    function testBurnTokens() public {
        uint256 initialSupply = 1000000 * 10 ** 18;
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
        CustomToken standaloneToken = new CustomToken("Standalone", "STAND", 1000000 * 10 ** 18, owner);

        // Approve first
        standaloneToken.approve(address(factory), 100);
        factory.burnTokens(address(standaloneToken), 100);
    }

    function testFailBurnTokensAsNonOwner() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000000 * 10 ** 18);
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

        CustomToken standaloneToken = new CustomToken("Standalone", "STAND", 1000, owner);

        assertTrue(factory.isTokenFromFactory(factoryToken));
        assertFalse(factory.isTokenFromFactory(address(standaloneToken)));
    }

    function testFuzzCreateToken(string memory name, string memory symbol, uint256 initialSupply) public {
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
        uint256 initialSupply = 1000000 * 10 ** 18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);

        // Ensure burn amount is not greater than initial supply
        burnAmount = bound(burnAmount, 0, initialSupply);

        // Approve the tokens first
        token.approve(address(factory), burnAmount);
        factory.burnTokens(tokenAddress, burnAmount);

        assertEq(token.balanceOf(address(this)), initialSupply - burnAmount);
    }

    // fee tests

    function testSetFeeDetails() public {
        uint256 feePercent = 500; // 5%

        vm.expectEmit(true, true, false, true);
        emit FeeUpdated(feeRecipient, feePercent);

        factory.setFeeDetails(feeRecipient, feePercent);

        (address configuredRecipient, uint256 configuredFee) = factory.getFeeDetails();
        assertEq(configuredRecipient, feeRecipient);
        assertEq(configuredFee, feePercent);
    }

    function testFailSetFeeDetailsTooHigh() public {
        factory.setFeeDetails(feeRecipient, 1001); // >10%
    }

    function testFailSetFeeDetailsAsNonOwner() public {
        vm.prank(user);
        factory.setFeeDetails(feeRecipient, 500);
    }

    function testTokenTransferWithFees() public {
        // Create token and set fee
        uint256 initialSupply = 1000 * 10 ** 18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);

        uint256 feePercent = 500; // 5%
        factory.setFeeDetails(feeRecipient, feePercent);

        // Transfer tokens
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 expectedFee = (transferAmount * feePercent) / 10000;
        uint256 expectedReceived = transferAmount - expectedFee;

        token.transfer(user, transferAmount);

        // Verify balances
        assertEq(token.balanceOf(user), expectedReceived);
        assertEq(token.balanceOf(feeRecipient), expectedFee);
        assertEq(token.balanceOf(address(this)), initialSupply - transferAmount);
    }

    function testTransferWithFeeRecipientChange() public {
        address newFeeRecipient = address(0x0101010101010101010101010101010101010101);
        uint256 initialSupply = 1000 * 10 ** 18;
        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);

        // Set initial fee and make transfer
        factory.setFeeDetails(feeRecipient, 500);
        token.transfer(user, 100 * 10 ** 18);

        // Change fee recipient and make another transfer
        factory.setFeeDetails(newFeeRecipient, 500);
        token.transfer(user, 100 * 10 ** 18);

        // Verify fees went to correct recipients
        assertEq(token.balanceOf(feeRecipient), 5 * 10 ** 18);
        assertEq(token.balanceOf(newFeeRecipient), 5 * 10 ** 18);
    }

    function testFuzzTokenTransferWithFees(uint256 feePercent, uint256 transferAmount) public {
        // Bound inputs to realistic values
        feePercent = bound(feePercent, 1, 1000);
        uint256 initialSupply = 1000000 * 10 ** 18;
        transferAmount = bound(transferAmount, 1, initialSupply);

        address tokenAddress = factory.createToken("Test Token", "TEST", initialSupply);
        CustomToken token = CustomToken(tokenAddress);

        factory.setFeeDetails(feeRecipient, feePercent);

        uint256 expectedFee = (transferAmount * feePercent) / 10000;
        uint256 expectedReceived = transferAmount - expectedFee;

        token.transfer(user, transferAmount);

        assertEq(token.balanceOf(user), expectedReceived);
        assertEq(token.balanceOf(feeRecipient), expectedFee);
    }

    function testTransferFromWithFees() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000 * 10 ** 18);
        CustomToken token = CustomToken(tokenAddress);

        factory.setFeeDetails(feeRecipient, 500);
        token.approve(user, 100 * 10 ** 18);

        vm.prank(user);
        token.transferFrom(address(this), address(0xB33F), 100 * 10 ** 18);

        assertEq(token.balanceOf(address(0xB33F)), 95 * 10 ** 18);
        assertEq(token.balanceOf(feeRecipient), 5 * 10 ** 18);
    }

    function testTransferWithZeroFee() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000 * 10 ** 18);
        CustomToken token = CustomToken(tokenAddress);

        factory.setFeeDetails(feeRecipient, 0);

        uint256 transferAmount = 100 * 10 ** 18;
        token.transfer(user, transferAmount);

        assertEq(token.balanceOf(user), transferAmount);
        assertEq(token.balanceOf(feeRecipient), 0);
    }

    function testTransferWithSmallAmounts() public {
        address tokenAddress = factory.createToken("Test Token", "TEST", 1000 * 10 ** 18);
        CustomToken token = CustomToken(tokenAddress);

        factory.setFeeDetails(feeRecipient, 500);
        token.transfer(user, 19); // Test with amount < 10000 (fee basis points)

        // Verify no dust is created and amounts add up
        uint256 totalSupply = token.totalSupply();
        assertEq(token.balanceOf(address(this)) + token.balanceOf(user) + token.balanceOf(feeRecipient), totalSupply);
    }
}
