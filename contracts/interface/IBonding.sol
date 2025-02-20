// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBonding {
    function updatePropose(address token, uint256 proposeId, string memory proposeDesc) external;
    function wrapToken() external view returns (address);
}
