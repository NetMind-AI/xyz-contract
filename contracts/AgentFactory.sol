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
    address public assetToken;                    // Base currency                                      
    address public tokenImplementation;           // Agent token implementation
    address public agentNFT;                      // XYZ agent NFT
    address public agentVault;                    // XYZ agent NFT Vault
    address public feeTo;                         // Fee reciver
    uint256 public fee;                           // Fee amount
    uint256 public fundThreshold;                 // Fund threshold


    address[] public allTokens;
    address[] public graduates;

    enum ApplicationStatus {
        Internal,
        Public
    }

    struct Application {
        string name;
        string symbol;
        address token;
        address fundPair;           // Internal Pair
        address dexPair;            // Public Pair
        address proposer;
        string  agentURI;           // Agent NFT tokenURI
        ApplicationStatus status;
    }

    mapping(uint256 => Application) private _applications;

    event GovUpdated(address oldGov, address newGov);
    event FundThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event NewApplication(uint256 id, string name, address token, address proposal);
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
        address assetToken_,
        address tokenImplementation_,
        address agentNFT_,
        address agentVault_,
        address feeTo_,
        uint256 fee_,
        uint256 fundThreshold_
    ) public initializer {
        gov = gov_;
        bonding = bonding_;
        assetToken = assetToken_;
        tokenImplementation = tokenImplementation_;
        agentNFT = agentNFT_;
        agentVault = agentVault_;
        feeTo = feeTo_;
        fee = fee_;
        fundThreshold = fundThreshold_;
    }

    function newApplication(
        address token,
        address fundPair,
        address proposer
    ) public onlyBonding returns(uint256 applicationId){
        IERC20(assetToken).safeTransferFrom(
            msg.sender,
            feeTo,
            fee
        );

        uint256 id = _nextId++;

        //Mint Agent NFT
        uint256 tokenId = IAgentNFT(agentNFT).safeMint(agentVault);
        string memory tokenURI = IAgentNFT(agentNFT).tokenURI(tokenId);
        
        string memory name = IERC20Metadata(token).name();
        string memory symbol = IERC20Metadata(token).symbol();
        
        Application memory application = Application(
            name,
            symbol,
            token,
            fundPair,
            address(0),
            proposer,
            tokenURI,
            ApplicationStatus.Internal
        );

        _applications[id] = application;
        allTokens.push(token);
        emit NewApplication(id, name, token, proposer);

        return id;
    }

    function graduate(uint256 id, address dexPair) public onlyBonding{
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
