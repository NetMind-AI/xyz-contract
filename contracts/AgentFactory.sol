// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interface/IAgentFactory.sol";
import "./interface/IAgentNFT.sol";

contract AgentFactory is
    IAgentFactory,
    Initializable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 private _nextId;          // ApplicationId
    address public gov;               // Gov contract, Dao or Management, not use
    address public bonding;           // Bonding contract
    address public agentNFT;          // XYZ agent NFT
    address public agentVault;        // XYZ agent NFT Vault

    address[] public allTokens;
    address[] public graduates;

    struct Application {
        string  name;                // Agent name
        address token;               // Agent token address
        string  agentURI;            // Agent NFT tokenURI
        address fundPair;            // Internal Pair
        address dexPair;             // Public Pair
        string  agentEID;            // Agent exist instance id
    }

    mapping(uint256 => Application) private _applications;
    mapping(address => uint256) private _applicationIds;
    mapping(bytes32 => bool) private _agentEIDs;



    event NewApplication(uint256 agentId, string name, address token, string sgentEID);
    event Graduate(uint256 id, address newDexPair);

    modifier onlyBonding() {
        require(msg.sender == bonding, "Only Bonding can execute");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address bonding_,
        address agentNFT_,
        address agentVault_
    ) public initializer {
        __Ownable_init(initialOwner);
        require(bonding_ != address(0) && agentNFT_ != address(0) && agentVault_ != address(0), "address err");
        bonding = bonding_;
        agentNFT = agentNFT_;
        agentVault = agentVault_;
    }

    function _registerAgentEID(string memory agentEID) internal  {
        require(bytes(agentEID).length > 0, "Agent EID cannot be empty");
        bytes32 hash = keccak256(abi.encodePacked(agentEID));
        require(!_agentEIDs[hash], "Agent EID already registered");
        _agentEIDs[hash] = true;
    }


    function newApplication(
        string memory name,
        string memory agentEID,
        address token,
        address fundPair
    ) public onlyBonding {
        _registerAgentEID(agentEID);
        uint256 id = ++_nextId;

        //Mint Agent NFT
        uint256 tokenId = IAgentNFT(agentNFT).safeMint(agentVault);
        string memory tokenURI = IAgentNFT(agentNFT).tokenURI(tokenId);

        Application memory application = Application(
            name,
            token,
            tokenURI,
            fundPair,
            address(0),
            agentEID
        );

        _applications[id] = application;
        _applicationIds[token] = id;

        allTokens.push(token);
        emit NewApplication(id, name, token, agentEID);
    }

    function graduate(address token, address dexPair) public onlyBonding{
        uint256 id = _applicationIds[token];
        require(id > 0, "No application with this token");
        Application storage app = _applications[id];
        app.dexPair = dexPair;

        graduates.push(app.token);

        emit Graduate(id, dexPair);
    }

    function getApplication(
        uint256 proposalId
    ) public view returns (Application memory) {
        return _applications[proposalId];
    }

    function totalAgents() public view returns (uint256) {
        return allTokens.length;
    }

    function setVault(address vault_) public onlyOwner{
        require(vault_ != address(0), "AgentFactory: Invalid vault address");
        agentVault = vault_;
    }

    function setBonding(address bonding_) public onlyOwner{
        require(bonding_ != address(0), "AgentFactory: Invalid Bonding address");
        bonding = bonding_;
    }

    function setAgentNFT(address agentNFT_) public onlyOwner{
        require(agentNFT_ != address(0), "AgentFactory: Invalid Agent NFT address");
        agentNFT = agentNFT_;
    }
}
