// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// on initialization owner is minted entire supply (1 billion), no mint functionality
// 4% fee on buying/selling aka transfers to/from pancakeswap router
// for this ^ add mapping of addresses which have fees, in case we have more than 1 dexes
// whitelist 0 fees mapping for from addresses (owner, dev, marketing)
// blacklist mapping cannot send tokens
// 3% fees to marketing, 1% dev - don't sell immediately
// anti snipe mechanism (might not be necessary due to 4% fee each way)
// addMassBlackList, removeMassBlackList

contract TLCToken is ERC20, Ownable {
    
    address public marketingAddress;
    address public devAddress;

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_TOTAL_FEE = 2500;
    
    mapping (address => uint256) public transferToDevFee;
    mapping (address => uint256) public transferFromDevFee;
    mapping (address => uint256) public transferToMarketingFee;
    mapping (address => uint256) public transferFromMarketingFee;
    mapping (address => bool) public feeWhitelist; // addresses which won't have a fee applied
    mapping (address => bool) public blacklist;

    event SetTransferToDevFee(address to, uint256 fee);
    event SetTransferFromDevFee(address from, uint256 fee);
    event SetTransferToMarketingFee(address to, uint256 fee);
    event SetTransferFromMarketingFee(address from, uint256 fee);
    event SetDevAddress(address devAddress);
    event SetMarketingAddress(address marketingAddress);

    constructor(
        address _devAddress,
        address _marketingAddress
    ) ERC20("TLC", "TLC") {
        devAddress = _devAddress;
        marketingAddress = _marketingAddress;

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
        if (feeWhitelist[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            uint256 marketingToFee = transferToMarketingFee[recipient];
            uint256 marketingFromFee = transferFromMarketingFee[sender];
            uint256 devToFee = (transferToDevFee[recipient] * amount) / FEE_DENOMINATOR;
            uint256 devFromFee = (transferFromDevFee[sender] * amount) / FEE_DENOMINATOR;
            uint256 devFee = devToFee + devFromFee;
            uint256 marketingFee = marketingToFee + marketingFromFee;
            uint256 finalAmount = amount - devFee - marketingFee;
            if (devFee > 0) {
                _transfer(sender, devAddress, devFee);
            }
            if (marketingFee > 0) {
                _transfer(sender, marketingAddress, marketingFee);
            }
            _transfer(sender, recipient, finalAmount);
        }

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function setTransferToDevFee(address _to, uint256 _fee) external onlyOwner {
        require(transferToMarketingFee[_to] + _fee < MAX_TOTAL_FEE, "MAX_TOTAL_FEE");
        transferToDevFee[_to] = _fee;
        emit SetTransferToDevFee(_to, _fee);
    }

    function setTransferFromDevFee(address _from, uint256 _fee) external onlyOwner {
        require(transferFromMarketingFee[_from] + _fee < MAX_TOTAL_FEE, "MAX_TOTAL_FEE");
        transferFromDevFee[_from] = _fee;
        emit SetTransferFromDevFee(_from, _fee);
    }

    function setTransferToMarketingFee(address _to, uint256 _fee) external onlyOwner {
        require(transferToDevFee[_to] + _fee < MAX_TOTAL_FEE, "MAX_TOTAL_FEE");
        transferToMarketingFee[_to] = _fee;
        emit SetTransferToMarketingFee(_to, _fee);
    }

    function setTransferFromMarketingFee(address _from, uint256 _fee) external onlyOwner {
        require(transferFromDevFee[_from] + _fee < MAX_TOTAL_FEE, "MAX_TOTAL_FEE");
        transferFromMarketingFee[_from] = _fee;
        emit SetTransferFromMarketingFee(_from, _fee);
    }
    
    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
        emit SetDevAddress(devAddress);
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner {
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

}
