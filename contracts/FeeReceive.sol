// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FeeReceive is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init(_msgSender());
    }

    function withdraw(address token, address to, uint256 amount) external nonReentrant() onlyOwner(){
        if(token == address(0)){
            require(address(this).balance >= amount, "Insufficient balance");
            payable(to).transfer(amount);
        }else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance");
            IERC20(token).safeTransfer(to, amount);
        }
    }

}
