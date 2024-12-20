// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IStakeVault.sol";

contract StakeVault is IStakeVault, OwnableUpgradeable{
    IERC20 public assetToken;
    uint256 public lockAmount;
    uint256 public lockTime;
    uint256 public lockPeriod;


    constructor() {
        _disableInitializers();
    }

    function initialize(address assetToken_, uint256 amount) external initializer {
        __Ownable_init(_msgSender());
        assetToken = IERC20(assetToken_);
        assetToken.transferFrom(_msgSender(), address(this), amount);
        lockAmount = amount;
        lockTime = block.timestamp;
        lockPeriod = 10 * 365 * 1 days;
    }

    function setLockPeriod(uint256 lockPeriod_) public onlyOwner(){
        lockPeriod = lockPeriod_;
    }

    function withdraw(address to) public onlyOwner(){
        require(block.timestamp >= lockTime + lockPeriod, "time error");
        assetToken.transfer(to, assetToken.balanceOf(address(this)));
    }

    function burn() public onlyOwner(){
        assetToken.transfer(address(0), assetToken.balanceOf(address(this)));
    }

}
