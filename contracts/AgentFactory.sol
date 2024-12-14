// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interface/IAgentFactory.sol";
import "./interface/IAgentNFT.sol";
import "./interface/IAgentToken.sol";



contract AgentFactory is
    IAgentFactory,
    Initializable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    
    bool    private locked;
    uint256 private _nextId;                      // ApplicationId
    address public gov;                           // Gov contract, Dao or Management
    address public assetToken;                    // Base currency                                      
    address public tokenImplementation;           // Agent token implementation
    address public agentNFT;                      // XYZ agent NFT
    address public agentVault;                    // XYZ agent NFT Vault
    address public feeTo;                         // Fee reciver
    uint256 public fee;                           // Fee amount
    uint256 public fundThreshold;                 // Fund threshold


    address[] public allTokens;

    enum ApplicationStatus {
        Internal,
        Public
    }

    struct Application {
        string name;
        string symbol;
        address token;
        address proposer;
        string  agentURI;           // Agent NFT tokenURI
        ApplicationStatus status;
    }

    mapping(uint256 => Application) private _applications;

    event GovUpdated(address oldGov, address newGov);
    event FundThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event NewApplication(uint256 id, string name, address token, address proposal);

    modifier onlyGov() {
        require(msg.sender == gov, "Only GOV can execute proposal");
        _;
    }

    modifier noReentrant() {
        require(!locked, "cannot reenter");
        locked = true;
        _;
        locked = false;
    }


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address gov_,
        address assetToken_,
        address tokenImplementation_,
        address agentNFT_,
        address agentVault_,
        address feeTo_,
        uint256 fee_,
        uint256 fundThreshold_
    ) public initializer {
        __Pausable_init();
        
        gov = gov_;
        assetToken = assetToken_;
        tokenImplementation = tokenImplementation_;
        agentNFT = agentNFT_;
        agentVault = agentVault_;
        feeTo = feeTo_;
        fee = fee_;
        fundThreshold = fundThreshold_;
        
    }

    function newApplication(
        string memory name, 
        string memory symbol,
        address proposer
    ) public returns(uint256 applicationId){
        IERC20(assetToken).safeTransferFrom(
            msg.sender,
            feeTo,
            fee
        );

        uint256 id = _nextId++;

        //C1: Mint Agent NFT
        uint256 tokenId = IAgentNFT(agentNFT).safeMint(agentVault);

        //C2: Clone Agent ERC20 Token
        address token = _createNewAgentToken(name, symbol);

        Application memory application = Application(
            name,
            symbol,
            token,
            proposer,
            IAgentNFT(agentNFT).tokenURI(tokenId),
            ApplicationStatus.Internal
        );

        _applications[id] = application;
        emit NewApplication(id, name, token, proposer);

        return id;
    }

    function getApplication(
        uint256 proposalId
    ) public view returns (Application memory) {
        return _applications[proposalId];
    }
    

    function _createNewAgentToken(
        string memory name,
        string memory symbol
    ) internal returns (address instance) {
        instance = Clones.clone(tokenImplementation);
        IAgentToken(instance).initialize(name, symbol);
        return instance;
    }

    function totalAgents() public view returns (uint256) {
        return allTokens.length;
    }
}
