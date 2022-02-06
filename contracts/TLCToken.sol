// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IWBNB.sol";


contract TLCToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IPancakeRouter02 private constant pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakeFactory private constant pancakeFactory = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    uint public constant MIN_SELL_AMOUNT = 1e18;
    
    address payable public marketingAddress;
    address payable public devAddress;

    // once fees accumulate to this amount, will sell before next buy
    uint public tokenSellAmount;

    bool private inSwap;
    address private pancakePair;

    uint public constant FEE_DENOMINATOR = 10000;
    uint public constant MAX_FEE = 2500;

    mapping (address => uint) public transferToFee;
    mapping (address => uint) public transferFromFee;
    
    mapping (address => bool) public feeWhitelist; // addresses which won't have a fee applied
    mapping (address => bool) public blacklist;

    event SetTokenSellAmount(uint tokenSellAmount);
    event SetTransferToFee(address to, uint fee);
    event SetTransferFromFee(address from, uint fee);
    event SetDevAddress(address devAddress);
    event SetMarketingAddress(address marketingAddress);

    modifier lockSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _owner,
        address payable _devAddress,
        address payable _marketingAddress,
        uint _tokenSellAmount
    ) ERC20("TLC", "TLC") {
        require(_owner != address(0), "0");
        require(_devAddress != address(0), "0");
        require(_marketingAddress != address(0), "0");
        devAddress = _devAddress;
        marketingAddress = _marketingAddress;
        tokenSellAmount = _tokenSellAmount;

        feeWhitelist[address(this)] = true;

        pancakePair = pancakeFactory.createPair(address(this), WBNB);
        _approve(address(this), address(pancakeRouter), type(uint).max);

        _transferOwnership(_owner);
        _mint(_owner, 1000000000 * 1e18);
    }

    function transfer(address recipient, uint amount) public virtual override returns (bool) {
        _tlcTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) public virtual override returns (bool) {
        if (tokenSellAmount > MIN_SELL_AMOUNT) _checkForSell(sender);
        _tlcTransfer(sender, recipient, amount);

        uint currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function setTokenSellAmount(uint _tokenSellAmount) external onlyOwner {
        tokenSellAmount = _tokenSellAmount;
        emit SetTokenSellAmount(tokenSellAmount);
    }

    function setTransferToFee(address _to, uint _fee) external onlyOwner {
        require(transferToFee[_to] < MAX_FEE, "MAX_FEE");
        transferToFee[_to] = _fee;
        emit SetTransferToFee(_to, _fee);
    }

    function setTransferFromFee(address _from, uint _fee) external onlyOwner {
        require(transferFromFee[_from] < MAX_FEE, "MAX_FEE");
        transferFromFee[_from] = _fee;
        emit SetTransferFromFee(_from, _fee);
    }

    function setDevAddress(address payable _devAddress) external onlyOwner {
        require(_devAddress != address(0), "Non zero address");
        devAddress = _devAddress;
        emit SetDevAddress(devAddress);
    }

    function setMarketingAddress(address payable _marketingAddress) external onlyOwner {
        require(_marketingAddress != address(0), "Non zero address");
        marketingAddress = _marketingAddress;
        emit SetMarketingAddress(marketingAddress);
    }

    function addWhitelist(address[] calldata addresses) external onlyOwner {
        require(addresses.length > 0, "Zero not allowed");
        for (uint i = 0; i < addresses.length; i++) {
            feeWhitelist[addresses[i]] = true;
        }
    }

    function removeWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            feeWhitelist[addresses[i]] = false;
        }
    }

    function addBlacklist(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = true;
        }
    }

    function removeBlacklist(address[] calldata addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = false;
        }
    }

    receive() external payable {}

    function _tlcTransfer(
        address sender,
        address recipient,
        uint amount
    ) private {
        require(!blacklist[sender] && !blacklist[recipient], "blacklisted");
        if (feeWhitelist[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            uint toFee = transferToFee[recipient];
            uint fromFee = transferFromFee[sender];
            uint fee = toFee + fromFee;
            uint feeAmount = (fee * amount) / FEE_DENOMINATOR;
            uint finalAmount = amount - feeAmount;
            if (feeAmount > 0) _transfer(sender, address(this), feeAmount);
            _transfer(sender, recipient, finalAmount);
        }
    }

    function _checkForSell(address sender) private {
        bool overMinTokenBalance = balanceOf(address(this)) >= tokenSellAmount;
        if (overMinTokenBalance && !inSwap && sender != pancakePair) {
            _swapTokensForBNB(tokenSellAmount);
            _sendBNBToTeam();
        }
    }

    function _swapTokensForBNB(uint _amount) private lockSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;

        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _sendBNBToTeam() private {
        uint balance = address(this).balance;
        uint devAmount = (balance / 100) * 25; // divide first to round down
        uint marketingAmount = (balance / 100) * 75;
        IWBNB(WBNB).deposit{ value: balance }();
        IERC20(WBNB).safeTransfer(devAddress, devAmount);
        IERC20(WBNB).safeTransfer(marketingAddress, marketingAmount);
    }

}
