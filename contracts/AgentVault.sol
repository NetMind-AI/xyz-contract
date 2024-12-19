// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IAgentNFT.sol";

contract AgentVault is Ownable, IERC721Receiver{
    event OutVault(address token, address to, uint256 tokenId);

    constructor(address initialOwner)
        Ownable(initialOwner)
    {}

    function safeTransfer(address token, address to, uint256 tokenId) onlyOwner public {
        IAgentNFT(token).safeTransferFrom(address(this), to, tokenId);

        emit OutVault(token, to, tokenId);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public override view returns (bytes4){
        require(operator != address(0) && from != address(this) && tokenId != 0 && data.length >= 0, "AgentVault: invalid transfer");
        return this.onERC721Received.selector;
    }
}
