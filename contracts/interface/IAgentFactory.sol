// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAgentFactory { 
    function totalAgents() external view returns (uint256);
    function newApplication(address token, address fundPair, address proposer) external returns (uint256);
    function graduate(uint256 id, address dexPair) external;
}