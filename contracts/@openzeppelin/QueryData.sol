// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBonding {
    function router() external view returns (address);
    function uniswapRouter() external view returns (address);
    function gradThreshold() external view returns (uint256);
    function tokenMsg(address token) external view returns (address, address, address, address);
}

interface IAgentToken {
    function totalSupply() external view returns (uint256);
    function fPair() external view returns (address);
    function liquidityPools() external view returns (address[] memory liquidityPools_);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

}

interface IFPair {
    function kLast() external view returns (uint256);
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

    struct Data {
        uint256 price;
        uint256 totalValue;
        uint256 fTokenBal;
        uint256 offsetToken;
        uint256 fNmtTokenBal;
        uint256 offsetNmt;
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

    function setNmtPair(address nmtPair_) public onlyOwner(){
        nmtPair = IUniswapV2Pair(nmtPair_);
    }

    function getTokenInfo(address token) public view returns(Data memory){
        Data memory data;
        uint256 threshold = bonding.gradThreshold();
        uint256 tokenBal;
        uint256 nmtTokenBal;
        uint256 nmtTotal;
        bool status;
        (data.price, data.totalValue, tokenBal, nmtTokenBal, nmtTotal, status, data.pair, data.governorToken, data.governor, data.timelock) = getTokenData(threshold, token);
        if(status){
            data.fTokenBal = tokenBal;
            data.fNmtTokenBal = nmtTokenBal;
            if(threshold < tokenBal){
                data.offsetToken = tokenBal - threshold;
            }
            if(nmtTotal > nmtTokenBal){
                data.offsetNmt = nmtTotal - nmtTokenBal;
            }
            data.totalNmt = nmtTotal;
        }else{
            data.sTokenBal = tokenBal;
            data.sNmtTokenBal = nmtTokenBal;
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
        uint256 nmtTokenBal;
        uint256 nmtTotal;
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
            (prices[i], totalValues[i], tokenBal, nmtTokenBal, nmtTotal, status, pairs[i], governorTokens[i], governors[i], timelocks[i]) = getTokenData(threshold, tokens[i]);
            if(status){
                fTokenBals[i] = tokenBal;
                fNmtTokenBals[i] = nmtTokenBal;
                if(threshold < tokenBal){
                    offsetTokens[i] = tokenBal - threshold;
                }
                if(nmtTotal > nmtTokenBal){
                    offsetNmts[i] = nmtTotal - nmtTokenBal;
                }
                totalNmts[i] = nmtTotal;
            }else{
                sTokenBals[i] = tokenBal;
                sNmtTokenBals[i] = nmtTokenBal;
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
        uint256 nmtTokenBal,
        uint256 nmtTotal,
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
        if(liquidityPools.length ==0){
            IFPair fpair = IFPair(fFactory.getPair(token, nmtToken));
            (uint256 tokenBal_, uint256 assetBal) = fpair.getReserves();
            tokenBal = tokenBal_;
            nmtTokenBal = IERC20(nmtToken).balanceOf(address(fpair));
            price = assetBal * 1e18 / tokenBal;
            nmtTotal = getNmtTotal(threshold, token);
            status = true;
        }else{
            (governorToken, governor, timelock, pair)= bonding.tokenMsg(token);
            IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(liquidityPools[0]);
            address token0 = uniswapV2Pair.token0();
            (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
            if(token0 == token){
                price = uint256(reserve1) *1e18 / uint256(reserve0);
                tokenBal = uint256(reserve0);
                nmtTokenBal = uint256(reserve1);
            }else{
                price = uint256(reserve0) *1e18 / uint256(reserve1);
                tokenBal = uint256(reserve1);
                nmtTokenBal = uint256(reserve0);
            }
        }
        totalValue = totalSupply * price / 1e18;
        return (price, totalValue, tokenBal, nmtTokenBal, nmtTotal, status, pair, governorToken, governor, timelock);
    }

    function getTokenPrices(address[] memory tokens) public view returns(uint256[] memory, uint256[] memory){
        uint256 nmtPrice = getNmtPrice();
        uint256 len = tokens.length;
        uint256[] memory tokenToNmtPrice = new uint256[](len);
        uint256[] memory tokenPrice = new uint256[](len);
        address token;
        for(uint i=0; i<len; i++){
            token = tokens[i];
            IAgentToken agentToken = IAgentToken(token);
            address[] memory liquidityPools = agentToken.liquidityPools();
            if(liquidityPools.length ==0){
                IFPair fpair = IFPair(fFactory.getPair(token, nmtToken));
                (uint256 tokenBal, uint256 assetBal) = fpair.getReserves();
                tokenToNmtPrice[i] = assetBal * 1e18 / tokenBal;
            }else{
                IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(liquidityPools[0]);
                address token0 = uniswapV2Pair.token0();
                (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
                if(token0 == token){
                    tokenToNmtPrice[i] = uint256(reserve1) *1e18 / uint256(reserve0);
                }else{
                    tokenToNmtPrice[i] = uint256(reserve0) *1e18 / uint256(reserve1);
                }
            }
            tokenPrice[i] = nmtPrice * tokenToNmtPrice[i] / 1e18;
        }
        return (tokenToNmtPrice, tokenPrice);
    }

    function getNmtPrice() public view returns(uint256 price){
        address token0 = nmtPair.token0();
        (uint112 reserve0, uint112 reserve1,) = nmtPair.getReserves();
        if(token0 == nmtToken){
            price = uint256(reserve1) *1e18 / uint256(reserve0);
        }else{
            price = uint256(reserve0) *1e18 / uint256(reserve1);
        }
    }

    function getNmtTotal(uint256 threshold, address token) public view returns(uint256){
        IFPair fpair = IFPair(fFactory.getPair(token, nmtToken));
        uint256 reserveA = IERC20(token).totalSupply();
        uint256 reserveB = fpair.kLast() / reserveA;
        return calculateAmountIn(uint128(reserveA), uint128(reserveB), uint128(reserveA) - uint128(threshold), fpair.kLast());
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
