// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IBonding {
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
        string motivation;
        string model;
    }

    struct Data {
        address token;
        string name;
        string ticker;
        uint256 supply;
        uint256 marketCap;
        uint256 price;
    }
    function wrapToken() external view returns (address);
    function router() external view returns (address);
    function uniswapRouter() external view returns (address);
    function gradThreshold() external view returns (uint256);
    function tokenMsg(address token) external view returns (address, address, address, address, uint256);
    function lunachMsg(address token) external view returns (uint256, uint256, uint256, uint256);
    function tokenInfo(address token) external view returns (Token memory);
}

interface IAgentToken {
    function totalSupply() external view returns (uint256);
    function fPair() external view returns (address);
    function liquidityPools() external view returns (address[] memory liquidityPools_);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

}

interface IFPair {
    function kLast() external view returns (uint256);
    function tokenA() external view returns (address);
    function tokenB() external view returns (address);
    function getReserves() external view returns (uint256, uint256);
}

interface IFRouter {
    function factory() external view returns (address);
    function assetToken() external view returns (address);
}

interface IFFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

contract QueryData is OwnableUpgradeable{
    IBonding public bonding;
    IFRouter public fRouter;
    IFFactory public fFactory;
    address public nmtToken;
    IUniswapV2Pair public nmtPair;
    mapping(address => address) public assetTokenPair;

    struct Data {
        uint256 price;
        uint256 totalValue;
        uint256 fTokenBal;
        uint256 offsetToken;
        uint256 fNmtTokenBal;
        uint256 offsetAssetToken;
        uint256 totalNmt;
        uint256 sTokenBal;
        uint256 sNmtTokenBal;
        address pair;
        address governorToken;
        address governor;
        address timelock;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address bonding_, address nmtPair_) external initializer {
        __Ownable_init(_msgSender());
        bonding = IBonding(bonding_);
        fRouter = IFRouter(bonding.router());
        fFactory = IFFactory(fRouter.factory());
        nmtToken = fRouter.assetToken();
        nmtPair = IUniswapV2Pair(nmtPair_);
    }

    function setAssetTokenPair(address[] memory assetTokens, address[] memory assetTokenPairs) public onlyOwner(){
        address assetToken;
        address assetPair;
        for (uint256 i = 0; i <= assetTokens.length; i++) {
            assetToken = assetTokens[i];
            if(assetToken == address(0))assetToken = bonding.wrapToken();
            (uint256 initSupply, , , ) = bonding.lunachMsg(assetToken);
            require(initSupply > 0, "assetToken err");
            assetPair = assetTokenPairs[i];
            require(IUniswapV2Pair(assetPair).token0() == assetToken || IUniswapV2Pair(assetPair).token1() == assetToken
                , "assetPair error");
            assetTokenPair[assetToken] = assetPair;
        }
    }

    function getTokenInfo(address token) public view returns(Data memory){
        Data memory data;
        uint256 threshold = bonding.gradThreshold();
        uint256 tokenBal;
        uint256 assetTokenBal;
        uint256 assetTokenTotal;
        bool status;
        (data.price, data.totalValue, tokenBal, assetTokenBal, assetTokenTotal, status, data.pair, data.governorToken, data.governor, data.timelock) = getTokenData(threshold, token);
        if(status){
            data.fTokenBal = tokenBal;
            data.fNmtTokenBal = assetTokenBal;
            IFPair fpair = IFPair(bonding.tokenInfo(token).pair);
            threshold = fpair.kLast() / assetTokenTotal;
            if(threshold < tokenBal){
                data.offsetToken = tokenBal - threshold;
            }
            if(assetTokenTotal > assetTokenBal){
                data.offsetAssetToken = assetTokenTotal - assetTokenBal;
            }
            data.totalNmt = assetTokenTotal;
        }else{
            data.sTokenBal = tokenBal;
            data.sNmtTokenBal = assetTokenBal;
        }
        return data;
    }

    function getTokenInfos(
        address[] memory tokens
    ) public view returns(
        uint256[] memory prices,
        uint256[] memory totalValues,
        uint256[] memory fTokenBals,
        uint256[] memory offsetTokens,
        uint256[] memory fNmtTokenBals,
        uint256[] memory offsetNmts,
        uint256[] memory totalNmts,
        uint256[] memory sTokenBals,
        uint256[] memory sNmtTokenBals,
        address[] memory pairs,
        address[] memory governorTokens,
        address[] memory governors,
        address[] memory timelocks
    ){
        uint256 len = tokens.length;
        uint256 threshold = bonding.gradThreshold();
        uint256 tokenBal;
        uint256 assetTokenBal;
        uint256 assetTokenTotal;
        prices = new uint256[](len);
        totalValues = new uint256[](len);
        fTokenBals = new uint256[](len);
        offsetTokens = new uint256[](len);
        fNmtTokenBals = new uint256[](len);
        offsetNmts = new uint256[](len);
        totalNmts = new uint256[](len);
        sTokenBals = new uint256[](len);
        sNmtTokenBals = new uint256[](len);
        pairs = new address[](len);
        governorTokens = new address[](len);
        governors = new address[](len);
        timelocks = new address[](len);
        bool status;
        for(uint i=0; i<len; i++){
            (prices[i], totalValues[i], tokenBal, assetTokenBal, assetTokenTotal, status, pairs[i], governorTokens[i], governors[i], timelocks[i]) = getTokenData(threshold, tokens[i]);
            if(status){
                fTokenBals[i] = tokenBal;
                fNmtTokenBals[i] = assetTokenBal;
                IFPair fpair = IFPair(bonding.tokenInfo(tokens[i]).pair);
                threshold = fpair.kLast() / assetTokenTotal;
                if(threshold < tokenBal){
                    offsetTokens[i] = tokenBal - threshold;
                }
                if(assetTokenTotal > assetTokenBal){
                    offsetNmts[i] = assetTokenTotal - assetTokenBal;
                }
                totalNmts[i] = assetTokenTotal;
            }else{
                sTokenBals[i] = tokenBal;
                sNmtTokenBals[i] = assetTokenBal;
            }
        }
    }

    function getTokenData(
        uint256 threshold,
        address token
    ) public view returns(
        uint256 price,
        uint256 totalValue,
        uint256 tokenBal,
        uint256 assetTokenBal,
        uint256 assetTokenTotal,
        bool status,
        address pair,
        address governorToken,
        address governor,
        address timelock
    ){
        uint256 totalSupply;
        IAgentToken agentToken = IAgentToken(token);
        totalSupply = agentToken.totalSupply();
        address[] memory liquidityPools = agentToken.liquidityPools();
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        if(liquidityPools.length ==0){
            IFPair fpair = IFPair(bonding.tokenInfo(token).pair);
            (uint256 tokenBal_, uint256 assetBal) = fpair.getReserves();
            tokenBal = tokenBal_;
            assetTokenBal = assetBal;
            assetTokenTotal= getNmtTotal(threshold, token);
            status = true;
        }else{
            (governorToken, governor, timelock, pair,)= bonding.tokenMsg(token);
            IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(liquidityPools[0]);
            address token0 = uniswapV2Pair.token0();
            (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
            if(token0 == token){
                tokenBal = uint256(reserve0);
                assetTokenBal = uint256(reserve1);
            }else{
                tokenBal = uint256(reserve1);
                assetTokenBal = uint256(reserve0);
            }
        }
        (uint256[] memory prices, ) = getTokenPrices(tokens);
        price = prices[0];
        totalValue = totalSupply * price / 1e18;
        return (price, totalValue, tokenBal, assetTokenBal, assetTokenTotal, status, pair, governorToken, governor, timelock);
    }

    function getTokenPrices(address[] memory tokens) public view returns(uint256[] memory, uint256[] memory){
        uint256 len = tokens.length;
        uint256[] memory tokenToAssetTokenPrice = new uint256[](len);
        uint256[] memory tokenPrice = new uint256[](len);
        address token;
        for(uint i=0; i<len; i++){
            token = tokens[i];
            IAgentToken agentToken = IAgentToken(token);
            address[] memory liquidityPools = agentToken.liquidityPools();
            IFPair fpair = IFPair(bonding.tokenInfo(token).pair);
            if(liquidityPools.length ==0){
                (uint256 tokenBal, uint256 assetBal) = fpair.getReserves();
                uint256 decimals1 = 18 - IERC20Metadata(fpair.tokenB()).decimals();
                tokenToAssetTokenPrice[i] = assetBal * (10**decimals1) * 1e18 / tokenBal;
            }else{
                IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(liquidityPools[0]);
                address token0 = uniswapV2Pair.token0();
                (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
                if(token0 == token){
                    tokenToAssetTokenPrice[i] = uint256(reserve1) *1e18 / uint256(reserve0);
                }else{
                    tokenToAssetTokenPrice[i] = uint256(reserve0) *1e18 / uint256(reserve1);
                }
            }
            tokenPrice[i] = getAssetTokenPrice(fpair.tokenB()) * tokenToAssetTokenPrice[i] / 1e18;
        }
        return (tokenToAssetTokenPrice, tokenPrice);
    }

    function getAssetTokenPrice(address assetToken) public view returns(uint256 price){
        IUniswapV2Pair pair = IUniswapV2Pair(assetTokenPair[assetToken]);
        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 decimals0 = 18 - IERC20Metadata(token0).decimals();
        uint256 decimals1 = 18 - IERC20Metadata(token1).decimals();
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if(token0 == assetToken){
            price = uint256(reserve1) * (10**decimals1) *1e18 / uint256(reserve0) / (10**decimals0);
        }else{
            price = uint256(reserve0)* (10**decimals0) *1e18 / uint256(reserve1) / (10**decimals1);
        }
    }

    function getNmtTotal(uint256 threshold, address token) public view returns(uint256){
        (, , , , uint256 assetTokenTotal)= bonding.tokenMsg(token);
        if(assetTokenTotal == 0){
            IFPair fpair = IFPair(bonding.tokenInfo(token).pair);
            uint256 reserveA = IERC20(token).totalSupply();
            uint256 reserveB = fpair.kLast() / reserveA;
            return calculateAmountIn(uint128(reserveA), uint128(reserveB), uint128(reserveA) - uint128(threshold), fpair.kLast());
        }else{
            return assetTokenTotal;
        }
    }

    function calculateAmountIn(
        uint128 reserveA,
        uint128 reserveB,
        uint128 amountOut,
        uint256 k
    ) public pure returns (uint128 amountIn) {
        require(amountOut < reserveA, "Invalid amountOut");
        uint256 newReserveA = uint256(reserveA) - uint256(amountOut);
        uint256 newReserveB = k / newReserveA;
        require(newReserveB > reserveB, "Invalid reserves");
        amountIn = uint128(newReserveB - uint256(reserveB));
        return amountIn;
    }

}
