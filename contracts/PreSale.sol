// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PreSale is Ownable {

    uint public bnbPerToken;
    uint public maxBnbPerUser;
    address public tokenAddress;

    mapping (address => bool) public whitelist;
    mapping (address => uint) public bnbSent;

    constructor(
        uint _bnbPerToken,
        uint _maxBnbPerUser,
        address _tokenAddress
    ) {
        bnbPerToken = _bnbPerToken;
        maxBnbPerUser = _maxBnbPerUser;
        tokenAddress = _tokenAddress;
    }

    receive() external payable {
        require(whitelist[msg.sender], "whitelist");
        require(bnbSent[msg.sender] + msg.value <= maxBnbPerUser, "bnb cap");
        
        bnbSent[msg.sender] += msg.value;
        uint tokenAmount = msg.value * 1e18 / bnbPerToken;
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
    }

    function setMaxBnbPerUser(uint _maxBnbPerUser) external onlyOwner {
        maxBnbPerUser = _maxBnbPerUser;
    }

    function addWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }

    function removeWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
    }

    function sendBNB() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    function sendToken(uint amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }

}