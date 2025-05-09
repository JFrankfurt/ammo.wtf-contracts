// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAmmoFactory {
    function getFeeDetails() external view returns (address recipient, uint256 feePercent);
}

contract AmmoToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    IAmmoFactory public immutable factory;

    event Redeemed(address indexed from, address indexed to, uint256 value, bytes encryptedData);

    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner)
        ERC20(name, symbol)
        ERC20Burnable()
        ERC20Permit(name)
        Ownable(owner)
    {
        factory = IAmmoFactory(msg.sender);
        _mint(owner, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Combines transfer with encrypted shipping data
     * @param to Recipient address -- should always be the store's current address
     * @param amount Amount of tokens to transfer
     * @param encryptedShippingData Encrypted payload containing shipping information
     * @return success Whether the operation succeeded
     */
    function redeem(address to, uint256 amount, bytes calldata encryptedShippingData) external returns (bool) {
        require(encryptedShippingData.length > 0, "Invalid shipping data");

        // Transfer tokens
        bool success = transfer(to, amount);

        if (success) {
            emit Redeemed(msg.sender, to, amount, encryptedShippingData);
        }

        return success;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) {
            // Skip fee for mint/burn
            (address feeRecipient, uint256 feePercent) = factory           .getFeeDetails();
            if (feePercent > 0) {
                uint256 feeAmount = (value * feePercent) / 10000; // Fee in basis points
                super._update(from, feeRecipient, feeAmount);
                super._update(from, to, value - feeAmount);
                return;
            }
        }
        super._update(from, to, value);
    }
}

contract AmmoFactory is Ownable, IAmmoFactory {
    event TokenCreated(address tokenAddress, string name, string symbol);
    event FeeUpdated(address recipient, uint256 feePercent);

    address[] public createdTokens;
    address public feeRecipient;
    uint256 public feePercent; // In basis points (1% = 100)

    constructor() Ownable(msg.sender) {}

    function setFeeDetails(address _feeRecipient, uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "Fee cannot exceed 10%"); // Max fee of 10%
        feeRecipient = _feeRecipient;
        feePercent = _feePercent;
        emit FeeUpdated(_feeRecipient, _feePercent);
    }

    function getFeeDetails() external view override returns (address recipient, uint256 _feePercent) {
        return (feeRecipient, feePercent);
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("Ownership cannot be renounced");
    }

    function createToken(string memory name, string memory symbol, uint256 initialSupply)
        public
        onlyOwner
        returns (address)
    {
        AmmoToken token = new AmmoToken(name, symbol, initialSupply, owner());
        createdTokens.push(address(token));
        emit TokenCreated(address(token), name, symbol);
        return address(token);
    }

    function burnTokens(address tokenAddress, uint256 amount) public onlyOwner {
        require(isTokenFromFactory(tokenAddress), "Token not created by this factory");
        AmmoToken token = AmmoToken(tokenAddress);
        require(token.balanceOf(owner()) >= amount, "Insufficient balance");
        token.burnFrom(owner(), amount);
    }

    function isTokenFromFactory(address tokenAddress) public view returns (bool) {
        for (uint256 i = 0; i < createdTokens.length; i++) {
            if (createdTokens[i] == tokenAddress) {
                return true;
            }
        }
        return false;
    }

    function getTokenCount() public view returns (uint256) {
        return createdTokens.length;
    }

    function getAllTokens() public view returns (address[] memory) {
        return createdTokens;
    }
}
