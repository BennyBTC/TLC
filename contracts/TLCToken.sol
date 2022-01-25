// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakeRouter02.sol";

// on initialization owner is minted entire supply (1 billion), no mint functionality
// 4% fee on buying/selling aka transfers to/from pancakeswap router
// for this ^ add mapping of addresses which have fees, in case we have more than 1 dexes
// whitelist 0 fees mapping for from addresses (owner, dev, marketing)
// blacklist mapping cannot send tokens
// 3% fees to marketing, 1% dev - don't sell immediately
// anti snipe mechanism (might not be necessary due to 4% fee each way)
// addMassBlackList, removeMassBlackList

contract TLCToken is ERC20, Ownable {

    IPancakeRouter02 private constant pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakeFactory private constant pancakeFactory = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    address payable public marketingAddress;
    address payable public devAddress;

    // once fees accumulate to this amount, will sell before next buy
    uint public tokenSellAmount;

    bool private inSwap;
    address private pancakePair;

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 2500;

    mapping (address => uint256) public transferToFee;
    mapping (address => uint256) public transferFromFee;
    
    mapping (address => bool) public feeWhitelist; // addresses which won't have a fee applied
    mapping (address => bool) public blacklist;

    event SetTransferToFee(address to, uint256 fee);
    event SetTransferFromFee(address from, uint256 fee);
    event SetDevAddress(address devAddress);
    event SetMarketingAddress(address marketingAddress);

    modifier lockSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address payable _devAddress,
        address payable _marketingAddress,
        uint _tokenSellAmount
    ) ERC20("TLC", "TLC") {
        devAddress = _devAddress;
        marketingAddress = _marketingAddress;
        tokenSellAmount = _tokenSellAmount;

        feeWhitelist[owner()] = true;
        feeWhitelist[address(this)] = true;

        pancakePair = pancakeFactory.createPair(address(this), WBNB);
        _approve(address(this), address(pancakeRouter), type(uint).max);

        _mint(_msgSender(), 1000000000 * 1e18);
    }


    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(!blacklist[_msgSender()], "blacklisted");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(!blacklist[sender], "blacklisted");
        _checkForSell(sender);
        if (feeWhitelist[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            uint256 toFee = transferToFee[recipient];
            uint256 fromFee = transferFromFee[sender];
            uint256 fee = toFee + fromFee;
            uint256 feeAmount = (fee * amount) / FEE_DENOMINATOR;
            uint256 finalAmount = amount - feeAmount;
            _transfer(sender, address(this), feeAmount);
            _transfer(sender, recipient, finalAmount);
        }

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function setTransferToFee(address _to, uint256 _fee) external onlyOwner {
        require(transferToFee[_to] < MAX_FEE, "MAX_FEE");
        transferToFee[_to] = _fee;
        emit SetTransferToFee(_to, _fee);
    }

    function setTransferFromFee(address _from, uint256 _fee) external onlyOwner {
        require(transferFromFee[_from] < MAX_FEE, "MAX_FEE");
        transferFromFee[_from] = _fee;
        emit SetTransferFromFee(_from, _fee);
    }

    function setDevAddress(address payable _devAddress) external onlyOwner {
        devAddress = _devAddress;
        emit SetDevAddress(devAddress);
    }

    function setMarketingAddress(address payable _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
        emit SetMarketingAddress(marketingAddress);
    }

    function addWhitelist(address[] calldata addresses) external onlyOwner {
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

    receive() external payable { }

    function _checkForSell(address sender) private {
        //address pancakePair = pancakeFactory.getPair(address(this), WBNB);
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
        uint devAmount = balance / 100 * 75; // divide first to round down
        uint marketingAmount = balance / 100 * 25;
        Address.sendValue(devAddress, devAmount);
        Address.sendValue(marketingAddress, marketingAmount);
    }


}
