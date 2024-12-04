// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Token contract template that will be deployed by the factory
contract CustomToken is ERC20 {
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
    // Event emitted when a new token is created
    event TokenCreated(address tokenAddress, string name, string symbol);
    
    // Array to keep track of all created tokens
    address[] public createdTokens;
    
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Creates a new ERC20 token
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of the token
     * @return The address of the newly created token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public onlyOwner returns (address) {
        CustomToken token = new CustomToken(
            name,
            symbol,
            initialSupply,
            msg.sender
        );
        
        createdTokens.push(address(token));
        emit TokenCreated(address(token), name, symbol);
        
        return address(token);
    }
    
    /**
     * @dev Burns a specified amount of tokens from the owner's balance
     * @param tokenAddress The address of the token to burn
     * @param amount The amount of tokens to burn
     */
    function burnTokens(address tokenAddress, uint256 amount) public onlyOwner {
        require(isTokenFromFactory(tokenAddress), "Token not created by this factory");
        
        CustomToken token = CustomToken(tokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        require(token.approve(address(this), amount), "Approval failed");
        require(token.transferFrom(msg.sender, address(0), amount), "Burn failed");
    }
    
    /**
     * @dev Checks if a token was created by this factory
     * @param tokenAddress The address to check
     * @return bool indicating if the token was created by this factory
     */
    function isTokenFromFactory(address tokenAddress) public view returns (bool) {
        for (uint i = 0; i < createdTokens.length; i++) {
            if (createdTokens[i] == tokenAddress) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Returns the number of tokens created by this factory
     * @return uint256 representing the total number of tokens created
     */
    function getTokenCount() public view returns (uint256) {
        return createdTokens.length;
    }
    
    /**
     * @dev Returns all tokens created by this factory
     * @return address[] array of token addresses
     */
    function getAllTokens() public view returns (address[] memory) {
        return createdTokens;
    }
}