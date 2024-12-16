// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interface/IAgentFactory.sol";
import "./interface/IAgentNFT.sol";

contract AgentFactory is
    IAgentFactory,
    Initializable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    
    uint256 private _nextId;                      // ApplicationId
    address public gov;                           // Gov contract, Dao or Management, not use
    address public bonding;                       // Bonding contract
    address public agentNFT;                      // XYZ agent NFT
    address public agentVault;                    // XYZ agent NFT Vault

    address[] public allTokens;
    address[] public graduates;

    struct Application {
        string  name;                // Agent name
        address token;               // Agent token address
        string  agentURI;            // Agent NFT tokenURI
        address fundPair;            // Internal Pair
        address dexPair;             // Public Pair
    }

    mapping(uint256 => Application) private _applications;
    mapping(address => uint256) private _applicationIds;

    event GovUpdated(address oldGov, address newGov);
    event FundThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event NewApplication(uint256 id, string name, address token);
    event Graduate(uint256 id, address newDexPair);

    modifier onlyGov() {
        require(msg.sender == gov, "Only GOV can execute proposal");
        _;
    }

    modifier onlyBonding() {
        require(msg.sender == gov, "Only Bonding can execute");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address gov_,
        address bonding_,
        address agentNFT_,
        address agentVault_
    ) public initializer {
        gov = gov_;
        bonding = bonding_;
        agentNFT = agentNFT_;
        agentVault = agentVault_;
    }

    function newApplication(
        string memory name,
        address token,
        address fundPair
    ) public onlyBonding {
        uint256 id = _nextId++;

        //Mint Agent NFT
        uint256 tokenId = IAgentNFT(agentNFT).safeMint(agentVault);
        string memory tokenURI = IAgentNFT(agentNFT).tokenURI(tokenId);
        
        Application memory application = Application(
            name,
            token,
            tokenURI,
            fundPair,
            address(0)
        );

        _applications[id] = application;
        _applicationIds[token] = id;

        allTokens.push(token);
        emit NewApplication(id, name, token);
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
}