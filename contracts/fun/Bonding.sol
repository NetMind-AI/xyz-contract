// SPDX-License-Identifier: MIT
// Modified from https://github.com/sourlodine/Pump.fun-Smart-Contract/blob/main/contracts/PumpFun.sol
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./FFactory.sol";
import "../interface/IFPair.sol";
import "./FRouter.sol";
import "../interface/IAgentToken.sol";
import "../interface/IAgentFactory.sol";
import "../interface/IUniswapV2Router.sol";
import "../interface/IUniswapV2Factory.sol";
import "../interface/IGovernor.sol";

contract Bonding is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    uint256 public constant K = 3_000_000_000_000;
    address public feeTo;
    FFactory public factory;
    FRouter public router;
    uint256 public initialSupply;
    uint256 public fee;
    uint256 public assetRate;
    uint256 public gradThreshold;
    IAgentFactory public agentFactory;
    IUniswapV2Router public uniswapRouter;
    address public agentTokenImpl;
    mapping(address => Token) public tokenInfo;
    address[] public tokenInfos;

    address public tokenAdmin;
    uint256 private taxSwapThresholdBasisPoints;
    uint256 private projectBuyTaxBasisPoints;
    uint256 private projectSellTaxBasisPoints;
    address private projectTaxRecipient;
    mapping(address => Msg) public tokenMsg;
    address private governorTokenImpl;
    address private governorImpl;
    address private timelockControllerImpl;
    address private defaultDelegatee;
    uint256 private timelockDelay;
    uint48 private votingDelay;
    uint32 private votingPeriod;
    uint256 private proposalThreshold;
    uint256 private quorumNumeratorValue;
    string[] private blockedWords;

    struct Token {
        address creator;
        address agentToken;
        address pair;
        Data data;
        string description;
        string image;
        string twitter;
        string telegram;
        string youtube;
        string website;
        string keyHash;
        bool trading;
        bool tradingOnUniswap;
    }

    struct Data {
        address token;
        string name;
        string ticker;
        uint256 supply;
        uint256 marketCap;
        uint256 price;
    }

    struct Msg {
        address governorToken;
        address governor;
        address timelock;
        address pair;
    }

    event Launched(address indexed token, address indexed pair);
    event Graduated(address indexed token, address indexed uniPair, address governorToken, address governor, address timelockController);
    event Twitter(address indexed token, string twitter);
    event Telegram(address indexed token, string telegram);
    event Youtube(address indexed token, string youtube);
    event Website(address indexed token, string website);
    event KeyHash(address indexed token, string keyHash);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address factory_,
        address router_,
        address feeTo_,
        uint256 fee_,
        uint256 initialSupply_,
        uint256 assetRate_,
        address agentFactory_,
        address uniswapRouter_,
        address tokenAdmin_,
        address agentTokenImpl_,
        address governorTokenImpl_,
        address governorImpl_,
        address timelockControllerImpl_,
        address defaultDelegatee_,
        uint256 gradThreshold_
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        require(feeTo_ != address(0) && factory_ != address(0) && router_ != address(0) && agentFactory_ != address(0) &&
        uniswapRouter_ != address(0) && tokenAdmin_ != address(0) && agentTokenImpl_ != address(0) && defaultDelegatee_ != address(0) &&
        governorTokenImpl_ != address(0) && governorImpl_ != address(0) && timelockControllerImpl_ != address(0), "address err");
        factory = FFactory(factory_);
        router = FRouter(router_);

        feeTo = feeTo_;
        fee = (fee_ * 1 ether) / 1000;

        initialSupply = initialSupply_;
        assetRate = assetRate_;

        agentFactory = IAgentFactory(agentFactory_);
        gradThreshold = gradThreshold_;
        uniswapRouter = IUniswapV2Router(uniswapRouter_);
        tokenAdmin = tokenAdmin_;
        agentTokenImpl = agentTokenImpl_;
        governorTokenImpl = governorTokenImpl_;
        governorImpl = governorImpl_;
        timelockControllerImpl = timelockControllerImpl_;
        defaultDelegatee = defaultDelegatee_;
    }

    function setInitialSupply(uint256 newSupply) public onlyOwner {
        initialSupply = newSupply;
    }

    function setDefaultDelegatee(address newDelegatee) public onlyOwner {
        require(newDelegatee != address(0), "address err");
        defaultDelegatee = newDelegatee;
    }

    function setGradThreshold(uint256 newThreshold) public onlyOwner {
        gradThreshold = newThreshold;
    }

    function addBlockedWord(string[] memory words) public onlyOwner {
        delete blockedWords;
        for (uint256 i = 0; i < words.length; i++) {
            blockedWords.push(words[i]);
        }
    }

    function setAgentTokenImpl(address newAgentTokenImpl) public onlyOwner {
        require(newAgentTokenImpl != address(0), "address err");
        agentTokenImpl = newAgentTokenImpl;
    }

    function setGovernorImpl(
        address newGovernorTokenImpl,
        address newGovernorImpl,
        address newTimelockImpl
    ) public onlyOwner {
        if(newGovernorTokenImpl != address(0))governorTokenImpl = newGovernorTokenImpl;
        if(newGovernorImpl != address(0))governorImpl = newGovernorImpl;
        if(newTimelockImpl != address(0))timelockControllerImpl = newTimelockImpl;
    }

    function setGovernorParm(
        uint256 newTimelockDelay,
        uint48 newVotingDelay,
        uint32 newVotingPeriod,
        uint256 newProposalThreshold,
        uint256 newQuorumNumerator
    ) public onlyOwner {
        require(newQuorumNumerator <100, "newQuorumNumerator err");
        timelockDelay = newTimelockDelay;
        votingDelay = newVotingDelay;
        votingPeriod = newVotingPeriod;
        proposalThreshold = newProposalThreshold;
        quorumNumeratorValue = newQuorumNumerator;
    }

    function setFee(uint256 newFee, address newFeeTo) public onlyOwner {
        fee = (newFee * 1 ether) / 1000;
        require(fee <= 1e22, "fee err");
        if(newFeeTo != address(0))feeTo = newFeeTo;
    }

    function setAssetRate(uint256 newRate) public onlyOwner {
        require(newRate > 0, "Rate err");
        assetRate = newRate;
    }

    function setTokenAdmin(address newTokenAdmin) public onlyOwner {
        require(newTokenAdmin != address(0), "address err");
        tokenAdmin = newTokenAdmin;
    }

    function setTokenMsg(
        address token,
        string memory twitter,
        string memory telegram,
        string memory youtube,
        string memory website,
        string memory keyHash
    ) public {
        address creator = tokenInfo[token].creator;
        if(bytes(twitter).length> 2 && auth(creator, token, bytes(tokenInfo[token].twitter).length)){
            tokenInfo[token].twitter = twitter;
            emit Twitter(token, twitter);
        }
        if(bytes(telegram).length > 2 && auth(creator, token, bytes(tokenInfo[token].telegram).length)){
            tokenInfo[token].telegram = telegram;
            emit Telegram(token, telegram);
        }
        if(bytes(youtube).length > 2 && auth(creator, token, bytes(tokenInfo[token].youtube).length)){
            tokenInfo[token].youtube = youtube;
            emit Youtube(token, youtube);
        }
        if(bytes(website).length > 2 && auth(creator, token, bytes(tokenInfo[token].website).length)){
            tokenInfo[token].website = website;
            emit Website(token, website);
        }
        if(bytes(keyHash).length > 2 && auth(creator, token, bytes(tokenInfo[token].keyHash).length)){
            tokenInfo[token].keyHash = keyHash;
            emit KeyHash(token, keyHash);
        }
    }

    function auth(address creator, address token, uint256 len) internal view returns(bool){
        address sender = _msgSender();
        return sender == tokenMsg[token].timelock || sender == owner() || (sender == creator && len <= 2);
    }

    function withdraw(address token, address to, uint256 amount) public onlyOwner {
        require(tokenMsg[token].governorToken != address(0), "token err");
        IGovernorToken governorToken = IGovernorToken(tokenMsg[token].governorToken);
        uint256 balance = governorToken.balanceOf(address(this));
        require(amount <= balance, "balance err");
        if(amount == 0)amount = balance;
        governorToken.withdraw(amount);
        IERC20(tokenMsg[token].pair).transfer(to, amount);
    }

    function delegate(address token, address delegatee) public onlyOwner {
        require(tokenMsg[token].governorToken != address(0) && delegatee != address(0), "addr err");
        IGovernorToken(tokenMsg[token].governorToken).delegate(delegatee);
    }

    function setTokenParm(
        uint256 taxSwapThresholdBasisPoints_,
        uint256 projectBuyTaxBasisPoints_,
        uint256 projectSellTaxBasisPoints_,
        address projectTaxRecipient_
    ) public onlyOwner {
        require(projectBuyTaxBasisPoints_ <= 1000 && projectSellTaxBasisPoints_ <= 1000, "tax error");
        taxSwapThresholdBasisPoints = taxSwapThresholdBasisPoints_;
        projectBuyTaxBasisPoints = projectBuyTaxBasisPoints_;
        projectSellTaxBasisPoints = projectSellTaxBasisPoints_;
        require(projectTaxRecipient_ != address(0), "address err");
        projectTaxRecipient = projectTaxRecipient_;
    }

    function getTokenParm() public view returns (uint256, uint256, uint256, address) {
        return (
            taxSwapThresholdBasisPoints,
            projectBuyTaxBasisPoints,
            projectSellTaxBasisPoints,
            projectTaxRecipient
        );
    }

    function getGovernorParm() public view returns (uint256, uint48, uint32, uint256, uint256) {
        return (
            timelockDelay,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumNumeratorValue
        );
    }

    function getGovernorMsg() public view returns (address, address, address, address) {
        return (
            governorTokenImpl,
            governorImpl,
            timelockControllerImpl,
            defaultDelegatee
        );
    }

    function getBlockedWords() public view returns (string[] memory) {
        return blockedWords;
    }

    function isValidName(string memory name) public view returns (bool) {
        string memory lowerName = toLower(name);
        for (uint256 i = 0; i < blockedWords.length; i++) {
            string memory lowerBlockedWord = toLower(blockedWords[i]);
            if (contains(lowerName, lowerBlockedWord)) {
                return false;
            }
        }
        return true;
    }

    function toLower(string memory str) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        for (uint i = 0; i < strBytes.length; i++) {
            uint8 char = uint8(strBytes[i]);
            if ((char >= 65) && (char <= 90)) {
                strBytes[i] = bytes1(char + 32);
            }
        }
        return string(strBytes);
    }

    function contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0 || haystackBytes.length < needleBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }

    function launch(
        string memory _name,
        string memory _ticker,
        string memory eid,
        string memory desc,
        string memory img,
        string[5] memory urls,
        uint256 purchaseAmount
    ) public nonReentrant {
        require(isValidName(_name), "name contains forbidden words");
        require(isValidName(_ticker), "ticker contains forbidden words");
        require(
            purchaseAmount > fee,
            "Purchase amount must be greater than fee"
        );
        address assetToken = router.assetToken();
        require(
            IERC20(assetToken).balanceOf(msg.sender) >= purchaseAmount,
            "Insufficient amount"
        );
        uint256 initialPurchase = (purchaseAmount - fee);
        IERC20(assetToken).safeTransferFrom(msg.sender, feeTo, fee);
        IERC20(assetToken).safeTransferFrom(
            msg.sender,
            address(this),
            initialPurchase
        );
        IAgentToken token = IAgentToken(Clones.clone(agentTokenImpl));

        address _pair = factory.createPair(address(token), assetToken);
        string memory name = string.concat(_name, " by NetMind XYZ");
        agentFactory.newApplication(
            name,
            eid,
            address(token),
            _pair
        );
        bytes memory tokenParams = abi.encode(
            initialSupply,
            taxSwapThresholdBasisPoints,
            projectBuyTaxBasisPoints,
            projectSellTaxBasisPoints,
            assetToken,
            _pair,
            address(this),
            projectTaxRecipient,
            tokenAdmin,
            address(uniswapRouter)
        );
        token.initialize(name, _ticker, tokenParams);
        uint256 supply = token.totalSupply();
        token.approve(address(router), supply);
        uint256 k = ((K * 10000) / assetRate);
        uint256 liquidity = ((k * 10000 ether) * 1 ether / supply)  / 10000;

        router.addInitialLiquidity(address(token), supply, liquidity);

        Data memory _data = Data({
            token: address(token),
            name: string.concat(_name, " by NetMind AI"),
            ticker: _ticker,
            supply: supply,
            marketCap: liquidity,
            price: IFPair(_pair).priceBLast()
        });
        Token memory tmpToken = Token({
            creator: msg.sender,
            agentToken: address(token),
            pair: _pair,
            data: _data,
            description: desc,
            image: img,
            twitter: urls[0],
            telegram: urls[1],
            youtube: urls[2],
            website: urls[3],
            keyHash:urls[4],
            trading: true,
            tradingOnUniswap: false
        });
        tokenInfo[address(token)] = tmpToken;
        tokenInfos.push(address(token));
        emit Launched(address(token), _pair);
        if(bytes(urls[0]).length> 2)emit Twitter(address(token), urls[0]);
        if(bytes(urls[1]).length > 2)emit Telegram(address(token), urls[1]);
        if(bytes(urls[2]).length > 2)emit Youtube(address(token), urls[2]);
        if(bytes(urls[3]).length > 2)emit Website(address(token), urls[3]);
        if(bytes(urls[4]).length > 2)emit KeyHash(address(token), urls[4]);

        // Make initial purchase
        IERC20(assetToken).forceApprove(address(router), initialPurchase);
        router.buy(initialPurchase, address(token), address(this));
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function sell(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenAddress
    ) public{
        require(tokenInfo[tokenAddress].trading, "Token not trading");
        (, uint256 amountOut) = router.sell(amountIn, tokenAddress, msg.sender );
        require(amountOut >= amountOutMin, "amountOutMin error");
        address pairAddress = factory.getPair(tokenAddress, router.assetToken());
        tokenInfo[tokenAddress].data.price = IFPair(pairAddress).priceBLast();
    }

    function buy(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenAddress
    ) public{
        require(tokenInfo[tokenAddress].trading, "Token not trading");
        (, uint256 amountOut) = router.buy(amountIn, tokenAddress, msg.sender );
        require(amountOut >= amountOutMin, "amountOutMin error");
        address pairAddress = factory.getPair(tokenAddress, router.assetToken());
        (uint256 reserveA, ) = IFPair(pairAddress).getReserves();
        tokenInfo[tokenAddress].data.price = IFPair(pairAddress).priceBLast();
        if (reserveA <= gradThreshold && tokenInfo[tokenAddress].trading) {
            _openTradingOnUniswap(tokenAddress);
        }
    }

    function _openTradingOnUniswap(address tokenAddress) private {
        IAgentToken token_ = IAgentToken(tokenAddress);
        Token storage _token = tokenInfo[tokenAddress];

        require(
            _token.trading && !_token.tradingOnUniswap,
            "trading is already open"
        );

        _token.trading = false;
        _token.tradingOnUniswap = true;
        address assetToken = router.assetToken();
        router.graduate(tokenAddress);
        address lp = _addInitialLiquidity(token_, IERC20(assetToken));
        agentFactory.graduate(address(token_), lp);
    }

    function _addInitialLiquidity(IAgentToken token_, IERC20 _assetToken) internal returns(address){
        address uniswapV2Pair_ = IUniswapV2Factory(uniswapRouter.factory()).getPair(
            address(token_),
            address(_assetToken)
        );
        if (uniswapV2Pair_ == address(0)) {
            uniswapV2Pair_ = IUniswapV2Factory(uniswapRouter.factory()).createPair(
                address(token_),
                address(_assetToken)
            );
        }
        token_.addLiquidityPool(uniswapV2Pair_);

        token_.approve(address(uniswapRouter), type(uint256).max);
        _assetToken.approve(address(uniswapRouter), type(uint256).max);
        // Add the liquidity:
        (, , uint256 lpTokens) = uniswapRouter
            .addLiquidity(
            address(token_),
            address(_assetToken),
            token_.balanceOf(address(this)),
            _assetToken.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
        token_.setTokenSta();
        _addGovernor(uniswapV2Pair_, lpTokens, token_, tokenInfo[address(token_)].data.name, tokenInfo[address(token_)].data.ticker);
        return uniswapV2Pair_;
    }

    function _addGovernor(address uniswapV2Pair_, uint256 lpTokens, IAgentToken token_, string memory name, string memory ticker) internal{
        tokenMsg[address(token_)].pair = uniswapV2Pair_;
        IGovernorToken governorToken = IGovernorToken(Clones.clone(governorTokenImpl));
        tokenMsg[address(token_)].governorToken = address(governorToken);
        IERC20(uniswapV2Pair_).approve(address(governorToken), lpTokens);
        governorToken.initialize(uniswapV2Pair_, string.concat("Staked ", name), string.concat("s", ticker), block.timestamp + 3650 days);
        governorToken.stake(lpTokens, defaultDelegatee);

        ITimelockController timelockController = ITimelockController(Clones.clone(timelockControllerImpl));
        tokenMsg[address(token_)].timelock = address(timelockController);

        IGovernor governor = IGovernor(Clones.clone(governorImpl));
        tokenMsg[address(token_)].governor = address(governor);
        governor.initialize(
            address(governorToken),
            address(timelockController),
            string.concat(name, " DAO"),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumNumeratorValue
        );

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(governor);
        executors[0] = address(governor);
        timelockController.initialize(timelockDelay, proposers, executors, address(0));
        emit Graduated(address(token_), uniswapV2Pair_, address(governorToken), address(governor), address(timelockController));
    }
}
