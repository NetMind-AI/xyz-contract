// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGovernor{
    function initialize(
        address token,
        address timelock,
        string memory name,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumeratorValue
    ) external;
}

interface ITimelockController{
    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) external;
}

interface IGovernorToken{
    function initialize(
        address tokenAddr,
        string memory name,
        string memory symbol,
        uint256 endTime
    ) external;
    function stake(uint256 amount, address delegatee) external;
    function setMatureAt(uint256 matureAt_) external;
    function delegate(address delegatee) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}
