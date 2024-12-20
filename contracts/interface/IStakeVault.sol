// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeVault{

    function setLockPeriod(uint256 lockPeriod) external;

    function withdraw(address to) external;

    function burn() external;

    function initialize(
        address assetToken_, 
        uint256 amount
    ) external;
}
