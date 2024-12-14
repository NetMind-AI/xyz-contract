// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./interface/IAgentNFT.sol";

contract AgentVault{
    address public gov;
    address public agentNFT;

    modifier OnlyGov(){
        require(msg.sender == gov, "Only Gov can call");
        _;
    }

    event OutValut(address to, uint256 tokenId);

    constructor (address agentNFT_, address gov_){
        agentNFT = agentNFT_;
        gov = gov_;
    }

    function safeTransfer(address to, uint256 tokenId) OnlyGov public {
        IAgentNFT(agentNFT).safeTransferFrom(address(this), to, tokenId);
        emit OutValut(to, tokenId);
    }
}