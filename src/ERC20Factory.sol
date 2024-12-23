// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomToken is ERC20, ERC20Burnable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
    }
}

contract ERC20Factory is Ownable {
    event TokenCreated(address tokenAddress, string name, string symbol);
    
    address[] public createdTokens;
    
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Blocks the renounceOwnership function from Ownable
     */
    function renounceOwnership() public virtual override onlyOwner {
        revert("Ownership cannot be renounced");
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public onlyOwner returns (address) {
        CustomToken token = new CustomToken(
            name,
            symbol,
            initialSupply,
            owner()
        );
        
        createdTokens.push(address(token));
        emit TokenCreated(address(token), name, symbol);
        
        return address(token);
    }
    
    function burnTokens(address tokenAddress, uint256 amount) public onlyOwner {
        require(isTokenFromFactory(tokenAddress), "Token not created by this factory");
        
        CustomToken token = CustomToken(tokenAddress);
        require(token.balanceOf(owner()) >= amount, "Insufficient balance");
        
        token.burnFrom(owner(), amount);
    }
    
    function isTokenFromFactory(address tokenAddress) public view returns (bool) {
        for (uint i = 0; i < createdTokens.length; i++) {
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