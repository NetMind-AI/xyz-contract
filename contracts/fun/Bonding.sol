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

contract Bonding is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 private taxSwapThresholdBasisPoints;
    uint256 private projectBuyTaxBasisPoints;
    uint256 private projectSellTaxBasisPoints;
    address private projectTaxRecipient;
    address public tokenAdmin;

    address public feeTo;
    FFactory public factory;
    FRouter public router;
    uint256 public initialSupply;
    uint256 public fee;
    uint256 public constant K = 3_000_000_000_000;
    uint256 public assetRate;
    uint256 public gradThreshold;
    address public agentFactory;
    address public uniswapRouter;
    address public agentTokenImpl;

    struct Profile {
        address user;
        address[] tokens;
    }

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
        string _name;
        string ticker;
        uint256 supply;
        uint256 price;
        uint256 marketCap;
        uint256 liquidity;
        uint256 volume;
        uint256 volume24H;
        uint256 prevPrice;
        uint256 lastUpdated;
    }

    mapping(address => Profile) public profile;
    address[] public profiles;

    mapping(address => Token) public tokenInfo;
    address[] public tokenInfos;

    event Launched(address indexed token, address indexed pair, uint);
    event Deployed(address indexed token, uint256 amount0, uint256 amount1);
    event Graduated(address indexed token, address agentToken);

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
        uint256 gradThreshold_
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        factory = FFactory(factory_);
        router = FRouter(router_);

        feeTo = feeTo_;
        fee = (fee_ * 1 ether) / 1000;

        initialSupply = initialSupply_;
        assetRate = assetRate_;

        agentFactory = agentFactory_;
        gradThreshold = gradThreshold_;
        uniswapRouter = uniswapRouter_;
        tokenAdmin = tokenAdmin_;
        agentTokenImpl = agentTokenImpl_;
    }

    function _createUserProfile(address _user) internal returns (bool) {
        address[] memory _tokens;
        Profile memory _profile = Profile({user: _user, tokens: _tokens});
        profile[_user] = _profile;
        profiles.push(_user);
        return true;
    }

    function _checkIfProfileExists(address _user) internal view returns (bool) {
        return profile[_user].user == _user;
    }

    function _approval(
        address _spender,
        address _token,
        uint256 amount
    ) internal returns (bool) {
        IERC20(_token).forceApprove(_spender, amount);
        return true;
    }

    function setInitialSupply(uint256 newSupply) public onlyOwner {
        initialSupply = newSupply;
    }

    function setGradThreshold(uint256 newThreshold) public onlyOwner {
        gradThreshold = newThreshold;
    }

    function setFee(uint256 newFee, address newFeeTo) public onlyOwner {
        fee = newFee;
        feeTo = newFeeTo;
    }

    function setAgentFactory(address agentFactory_) public onlyOwner {
        agentFactory = agentFactory_;
    }

    function setAssetRate(uint256 newRate) public onlyOwner {
        require(newRate > 0, "Rate err");
        assetRate = newRate;
    }

    function setTokenAdmin(address newTokenAdmin) public onlyOwner {
        tokenAdmin = newTokenAdmin;
    }

    function setTokenParm(
        uint256 taxSwapThresholdBasisPoints_,
        uint256 projectBuyTaxBasisPoints_,
        uint256 projectSellTaxBasisPoints_,
        address projectTaxRecipient_
    ) public onlyOwner {
        taxSwapThresholdBasisPoints = taxSwapThresholdBasisPoints_;
        projectBuyTaxBasisPoints = projectBuyTaxBasisPoints_;
        projectSellTaxBasisPoints = projectSellTaxBasisPoints_;
        projectTaxRecipient = projectTaxRecipient_;
    }

    function getUserTokens(
        address account
    ) public view returns (address[] memory) {
        require(_checkIfProfileExists(account), "User Profile dose not exist.");
        Profile memory _profile = profile[account];
        return _profile.tokens;
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
        string memory desc,
        string memory img,
        string[4] memory urls,
        uint256 purchaseAmount
    ) public nonReentrant returns (address, address, uint) {
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
        bytes memory tokenParams = abi.encode(
            initialSupply,
            taxSwapThresholdBasisPoints,
            projectBuyTaxBasisPoints,
            projectSellTaxBasisPoints,
            assetToken,
            _pair,
            address(this),
            projectTaxRecipient,
            uniswapRouter,
            tokenAdmin
        );
        token.initialize(string.concat(_name, " by NetMind AI"), _ticker, tokenParams);
        uint256 supply = token.totalSupply();
        bool approved = _approval(address(router), address(token), supply);
        require(approved);

        uint256 k = ((K * 10000) / assetRate);
        uint256 liquidity = (((k * 10000 ether) / supply) * 1 ether) / 10000;

        router.addInitialLiquidity(address(token), supply, liquidity);

        Data memory _data = Data({
            token: address(token),
            name: string.concat(_name, " by NetMind AI"),
            _name: _name,
            ticker: _ticker,
            supply: supply,
            price: supply / liquidity,
            marketCap: liquidity,
            liquidity: liquidity * 2,
            volume: 0,
            volume24H: 0,
            prevPrice: supply / liquidity,
            lastUpdated: block.timestamp
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
            trading: true, // Can only be traded once creator made initial purchase
            tradingOnUniswap: false
        });
        tokenInfo[address(token)] = tmpToken;
        tokenInfos.push(address(token));

        bool exists = _checkIfProfileExists(msg.sender);

        if (exists) {
            Profile storage _profile = profile[msg.sender];

            _profile.tokens.push(address(token));
        } else {
            bool created = _createUserProfile(msg.sender);

            if (created) {
                Profile storage _profile = profile[msg.sender];

                _profile.tokens.push(address(token));
            }
        }

        uint n = tokenInfos.length;

        emit Launched(address(token), _pair, n);

        // Make initial purchase
        IERC20(assetToken).forceApprove(address(router), initialPurchase);
        router.buy(initialPurchase, address(token), address(this));
        token.transfer(msg.sender, token.balanceOf(address(this)));

        return (address(token), _pair, n);
    }

    function sell(
        uint256 amountIn,
        address tokenAddress
    ) public returns (bool) {
        require(tokenInfo[tokenAddress].trading, "Token not trading");

        address pairAddress = factory.getPair(
            tokenAddress,
            router.assetToken()
        );

        IFPair pair = IFPair(pairAddress);

        (uint256 reserveA, uint256 reserveB) = pair.getReserves();

        (uint256 amount0In, uint256 amount1Out) = router.sell(
            amountIn,
            tokenAddress,
            msg.sender
        );

        uint256 newReserveA = reserveA + amount0In;
        uint256 newReserveB = reserveB - amount1Out;
        uint256 duration = block.timestamp -
            tokenInfo[tokenAddress].data.lastUpdated;

        uint256 liquidity = newReserveB * 2;
        uint256 mCap = (tokenInfo[tokenAddress].data.supply * newReserveB) /
            newReserveA;
        uint256 price = newReserveA / newReserveB;
        uint256 volume = duration > 86400
            ? amount1Out
            : tokenInfo[tokenAddress].data.volume24H + amount1Out;
        uint256 prevPrice = duration > 86400
            ? tokenInfo[tokenAddress].data.price
            : tokenInfo[tokenAddress].data.prevPrice;

        tokenInfo[tokenAddress].data.price = price;
        tokenInfo[tokenAddress].data.marketCap = mCap;
        tokenInfo[tokenAddress].data.liquidity = liquidity;
        tokenInfo[tokenAddress].data.volume =
            tokenInfo[tokenAddress].data.volume +
            amount1Out;
        tokenInfo[tokenAddress].data.volume24H = volume;
        tokenInfo[tokenAddress].data.prevPrice = prevPrice;

        if (duration > 86400) {
            tokenInfo[tokenAddress].data.lastUpdated = block.timestamp;
        }

        return true;
    }

    function buy(
        uint256 amountIn,
        address tokenAddress
    ) public payable returns (bool) {
        require(tokenInfo[tokenAddress].trading, "Token not trading");

        address pairAddress = factory.getPair(
            tokenAddress,
            router.assetToken()
        );

        IFPair pair = IFPair(pairAddress);

        (uint256 reserveA, uint256 reserveB) = pair.getReserves();

        (uint256 amount1In, uint256 amount0Out) = router.buy(
            amountIn,
            tokenAddress,
            msg.sender
        );

        uint256 newReserveA = reserveA - amount0Out;
        uint256 newReserveB = reserveB + amount1In;
        uint256 duration = block.timestamp -
            tokenInfo[tokenAddress].data.lastUpdated;

        uint256 liquidity = newReserveB * 2;
        uint256 mCap = (tokenInfo[tokenAddress].data.supply * newReserveB) /
            newReserveA;
        uint256 price = newReserveA / newReserveB;
        uint256 volume = duration > 86400
            ? amount1In
            : tokenInfo[tokenAddress].data.volume24H + amount1In;
        uint256 _price = duration > 86400
            ? tokenInfo[tokenAddress].data.price
            : tokenInfo[tokenAddress].data.prevPrice;

        tokenInfo[tokenAddress].data.price = price;
        tokenInfo[tokenAddress].data.marketCap = mCap;
        tokenInfo[tokenAddress].data.liquidity = liquidity;
        tokenInfo[tokenAddress].data.volume =
            tokenInfo[tokenAddress].data.volume +
            amount1In;
        tokenInfo[tokenAddress].data.volume24H = volume;
        tokenInfo[tokenAddress].data.prevPrice = _price;

        if (duration > 86400) {
            tokenInfo[tokenAddress].data.lastUpdated = block.timestamp;
        }

        if (newReserveA <= gradThreshold && tokenInfo[tokenAddress].trading) {
            _openTradingOnUniswap(tokenAddress);
        }

        return true;
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
        // Transfer asset tokens to bonding contract
        address pairAddress = factory.getPair(
            tokenAddress,
            assetToken
        );

        IFPair pair = IFPair(pairAddress);

        uint256 assetBalance = pair.assetBalance();
        uint256 tokenBalance = pair.balance();

        router.graduate(tokenAddress);
        token_.createPair();
        address lp = token_.liquidityPools()[0];
        IERC20(assetToken).transfer(tokenAddress, assetBalance);
        token_.transfer(tokenAddress, tokenBalance);
        token_.addInitialLiquidity(address(this));

    }


}