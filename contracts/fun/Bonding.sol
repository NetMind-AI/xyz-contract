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
import "../interface/IStakeVault.sol";
import "../interface/IUniswapV2Router.sol";
import "../interface/IUniswapV2Factory.sol";

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
    address public stakeVaultImpl;
    mapping(address => address) public tokenStake;


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

    event Launched(address indexed token, address indexed pair);
    event Graduated(address indexed token, address indexed uniPair);
    event Twitter(address indexed token, string twitter);
    event Telegram(address indexed token, string telegram);
    event Youtube(address indexed token, string youtube);
    event Website(address indexed token, string website);

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
        address stakeVaultImpl_,
        uint256 gradThreshold_
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        require(feeTo_ != address(0) && factory_ != address(0) && router_ != address(0) && agentFactory_ != address(0) &&
        uniswapRouter_ != address(0) && tokenAdmin_ != address(0) && agentTokenImpl_ != address(0) && stakeVaultImpl_ != address(0), "address err");
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
        stakeVaultImpl = stakeVaultImpl_;
    }

    function setInitialSupply(uint256 newSupply) public onlyOwner {
        initialSupply = newSupply;
    }

    function setGradThreshold(uint256 newThreshold) public onlyOwner {
        gradThreshold = newThreshold;
    }

    function setAgentTokenImpl(address newAgentTokenImpl) public onlyOwner {
        require(newAgentTokenImpl != address(0), "address err");
        agentTokenImpl = newAgentTokenImpl;
    }

    function setStakeVaultImpl(address newStakeVaultImpl) public onlyOwner {
        require(newStakeVaultImpl != address(0), "address err");
        stakeVaultImpl = newStakeVaultImpl;
    }

    function setFee(uint256 newFee, address newFeeTo) public onlyOwner {
        fee = (newFee * 1 ether) / 1000;
        require(fee <= 1e22, "fee err");
        require(newFeeTo != address(0), "address err");
        feeTo = newFeeTo;
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
        string memory website
    ) public {
        address creator = tokenInfo[token].creator;
        if(bytes(twitter).length> 0 && auth(creator, bytes(tokenInfo[token].twitter).length)){
            tokenInfo[token].twitter = twitter;
            emit Twitter(token, twitter);
        }
        if(bytes(telegram).length > 0 && auth(creator, bytes(tokenInfo[token].telegram).length)){
            tokenInfo[token].telegram = telegram;
            emit Telegram(token, telegram);
        }
        if(bytes(youtube).length > 0 && auth(creator, bytes(tokenInfo[token].youtube).length)){
            tokenInfo[token].youtube = youtube;
            emit Youtube(token, youtube);
        }
        if(bytes(website).length > 0 && auth(creator, bytes(tokenInfo[token].website).length)){
            tokenInfo[token].website = website;
            emit Website(token, website);
        }
    }

    function auth(address creator, uint256 len) internal view returns(bool){
        return _msgSender() == owner() || (_msgSender() == creator && len == 0);
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

    function launch(
        string memory _name,
        string memory _ticker,
        string memory eid,
        string memory desc,
        string memory img,
        string[4] memory urls,
        uint256 purchaseAmount
    ) public nonReentrant {
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
            trading: true,
            tradingOnUniswap: false
        });
        tokenInfo[address(token)] = tmpToken;
        tokenInfos.push(address(token));
        emit Launched(address(token), _pair);
        if(bytes(urls[0]).length> 0)emit Twitter(address(token), urls[0]);
        if(bytes(urls[1]).length > 0)emit Telegram(address(token), urls[1]);
        if(bytes(urls[2]).length > 0)emit Youtube(address(token), urls[2]);
        if(bytes(urls[3]).length > 0)emit Website(address(token), urls[3]);

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
        emit Graduated(address(token_), lp);
    }

    function _addInitialLiquidity(IAgentToken token_, IERC20 _assetToken) internal returns(address){
        address uniswapV2Pair_ = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(token_),
            address(_assetToken)
        );
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
        IStakeVault stakeVault = IStakeVault(Clones.clone(stakeVaultImpl));
        tokenStake[address(token_)] = address(stakeVault);
        IERC20(uniswapV2Pair_).approve(address(stakeVault), lpTokens);
        stakeVault.initialize(uniswapV2Pair_, lpTokens);
        return uniswapV2Pair_;
    }

}
