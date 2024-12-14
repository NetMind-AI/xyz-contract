// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAgentFactory { 
    function totalAgents() external view returns (uint256);
    function newApplication(string memory name, string memory symbal, address proposer) external returns (uint256);
}