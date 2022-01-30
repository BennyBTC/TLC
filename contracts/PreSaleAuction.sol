// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PreSaleAuction is Ownable {

    address public tokenAddress;
    uint public currentCliff;
    uint public totalSold;

    uint public constant MAX_BUY_AMOUNT = 111 * 1e18; // to make sure we can pass 2 cliffs in one buy

    uint[5] public amountSoldPriceCliffs = [
        0,
        1000000 * 1e18,
        2000000 * 1e18,
        3000000 * 1e18,
        4000000 * 1e18
    ];

    uint[5] public priceCliffs = [
        11 * 1e13, // 0.00011 BNB
        16 * 1e13, // 0.00016 BNB
        21 * 1e13, // 0.00021 BNB
        26 * 1e13, // 0.00026 BNB
        31 * 1e13  // 0.00031 BNB
    ];

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    receive() external payable {
        require(msg.value <= MAX_BUY_AMOUNT, "MAX_BUY_AMOUNT");

        uint bnbPerToken = _getCurrentBnbPerToken(currentCliff);
        uint tokenAmount = (msg.value * 1e18) / bnbPerToken;
        if (currentCliff == 4) {
            require(IERC20(tokenAddress).balanceOf(address(this)) > tokenAmount, "NOT ENOUGH TOKENS");
            IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
            totalSold += tokenAmount;
            return;
        }

        uint nextCliffAmount = amountSoldPriceCliffs[currentCliff + 1];
        // if user is buying two price ranges
        if (totalSold + tokenAmount > nextCliffAmount) {
            uint purchase1Amount = nextCliffAmount - totalSold;
            uint bnbForPurchase1 = (purchase1Amount * 1e18) / bnbPerToken;
            uint bnbForPurchase2 = msg.value - bnbForPurchase1;
            uint newBnbPerToken = _getCurrentBnbPerToken(currentCliff + 1);
            uint purchase2Amount = (bnbForPurchase2 * 1e18) / newBnbPerToken;
            totalSold += purchase1Amount + purchase2Amount;
            currentCliff++;
            IERC20(tokenAddress).transfer(msg.sender, purchase1Amount + purchase2Amount);
        } else {
            IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
            totalSold += tokenAmount;
            if (totalSold == nextCliffAmount) {
                currentCliff++;
            }
        }
    }

    function getExpectedReturn(uint bnbAmount) external view returns (uint) {

    }

    function getRequiredBnb(uint tokenAmount) external view returns (uint) {

    }

    function sendBNB() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    function sendToken(uint amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    function _getCurrentBnbPerToken(uint _currentCliff) private view returns (uint) {
        return priceCliffs[_currentCliff];
    }

}