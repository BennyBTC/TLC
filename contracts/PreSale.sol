// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PreSale is Ownable {
    using Address for address;

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

}